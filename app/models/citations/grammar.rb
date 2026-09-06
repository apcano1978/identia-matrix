# frozen_string_literal: true

module Citations
  # La gramática de citas de matrix. CONGELADA EN F0.
  #
  # Los artefactos son inmutables: una cita mal formada, o una gramática que
  # cambia a mitad de camino, se queda para siempre dentro de un markdown que
  # nadie puede reescribir. Por eso esto vive aquí, con sus tests, antes de que
  # exista un solo modelo de dominio.
  #
  #   [src:<kind>/<locator>[#<anchor>][@<suffix>]]
  #
  # kind      code | doc | meet | note | spec | dod | verify | pkg | close
  # locator   <repo>:<path>   en code y verify — el CALIFICADOR DE REPOSITORIO
  #                           es obligatorio: con varios repositorios es lo
  #                           único que distingue de cuál se habla.
  #           <slug>          en doc, spec, dod, pkg, close
  #           <YYYY-MM-DD>    en meet, con sufijo opcional
  #           <YYYY-MM-DD>    en note, con autor opcional y, tras él, ordinal
  # anchor    #L<n> | #p<n> | #§<n> | #c<n> | #deploy
  # suffix    @<sha7>   en code y verify
  #           @HH:MM    en meet
  #
  # Ejemplos reales, tomados de la maqueta aprobada:
  #
  #   [src:code/booking-core:cache.ts#L88@4f2a9c1]
  #   [src:doc/acta-precios#p2]
  #   [src:meet/2026-05-02@22:40]
  #   [src:note/2026-05-08-ap]
  #   [src:dod/dod-031#c3]
  #   [src:verify/pricing-svc:run-174#L88]
  #
  # ── Tres enmiendas, todas ADITIVAS ──────────────────────────────────────
  #
  # 1. `close` como noveno tipo, el 5 de agosto de 2026. Sin él TANK no podía
  #    citar la fuente al afirmar que un evolutivo revierte una decisión de
  #    otro, que es el valor central del sistema:  [src:close/close-002#§3]
  #
  # 2. Sufijo opcional en las reuniones, el 5 de agosto de 2026, porque la fecha
  #    sola no distingue dos el mismo día. La forma corta sigue valiendo:
  #      [src:meet/2026-05-02@22:40]
  #      [src:meet/2026-05-02-unificacion-precio@22:40]
  #
  # 3. Sufijo ordinal en las notas, decidido el 26 de agosto de 2026. La
  #    gramática solo admitía una nota citable por autor y día, y la segunda
  #    daba un 500: nadie rescataba el RecordInvalid. Va ANIDADO tras el autor,
  #    y el porqué está en AUTHOR, más abajo:
  #      [src:note/2026-08-17-ap]
  #      [src:note/2026-08-17-ap-2]
  #
  # Se pudieron hacer porque todavía no existía ningún artefacto real: solo el
  # seed, que se regenera. LA VENTANA SE CERRÓ EL 4 DE SEPTIEMBRE DE 2026, cuando
  # TANK produjo el primero de verdad.
  #
  # 4. `acta` como décimo tipo, y el ancla `#abierta-N`, en F11:
  #      [src:acta/arquitecto-031#abierta-1]
  #
  #    ⚠ ESTA SE HACE CON LA VENTANA YA CERRADA, y hace falta decir por qué no
  #    es una excepción de conveniencia. Al releer la regla apareció que **no
  #    todas las enmiendas aditivas son iguales**:
  #
  #    · Añadir un TIPO QUE NO EXISTÍA no puede cambiar cómo se interpreta
  #      ninguna cita ya emitida, porque no hay texto anterior que empiece por
  #      `[src:acta/`. No es una promesa: hay un test que lo comprueba cita a
  #      cita sobre el corpus entero (test/models/citations/amendments_test.rb).
  #
  #    · Tocar la FORMA DE UN TIPO EXISTENTE sí puede, y ahí el peligro es real:
  #      es exactamente lo que hizo delicada la enmienda 3, donde un sufijo
  #      suelto habría hecho parsear `note/<fecha>-antonio` SIN autor.
  #
  #    Lo que sigue sin caber: cambiar la forma de un tipo existente, hacer
  #    opcional algo obligatorio, o mover un sufijo de sitio.
  module Grammar
    # Los diez tipos de fuente. El nivel de procedencia NO se almacena: se
    # deriva de aquí. Un dato derivable no puede desincronizarse.
    #
    # `acta` es de nivel ORIGEN: recoge decisiones de una persona, tomadas en una
    # conversación. El ARQUITECTO transcribe; quien decide es quien contesta.
    ORIGIN_KINDS  = %w[code doc meet note acta].freeze
    DERIVED_KINDS = %w[spec dod verify pkg close].freeze

    # ⚠ KINDS NO SE COMPONE DE LAS DOS LISTAS, y tiene que quedarse así.
    #
    # De aquí sale el enum `Citation#source_kind`, que es una COLUMNA ENTERA y
    # por tanto POSICIONAL. Compuesto —`ORIGIN_KINDS + DERIVED_KINDS`—, añadir
    # `acta` al final de los de origen lo habría metido en la posición 4 y habría
    # desplazado `spec, dod, verify, pkg, close` de 4-8 a 5-9: todas las citas ya
    # almacenadas cambiarían de tipo en silencio, dentro de artefactos que nadie
    # puede reescribir.
    #
    # Escrito a mano y con lo nuevo ANEXADO AL FINAL, el orden es un hecho del
    # repositorio y no un efecto colateral de en qué lista se declaró un tipo.
    # Hay un test que fija los enteros uno a uno.
    KINDS = %w[code doc meet note spec dod verify pkg close acta].freeze

    # Los tipos que exigen calificador de repositorio en el locator.
    REPOSITORY_QUALIFIED_KINDS = %w[code verify].freeze

    # Los tipos cuyo locator es una fecha.
    DATED_KINDS = %w[meet note].freeze

    # Los tipos cuyo locator es el `code` de un artefacto. NO es lo mismo que
    # DERIVED_KINDS, y desde F11 la diferencia va en las DOS direcciones:
    #
    # · `verify` es derivado y NO es artefacto: su locator es <repo>:<run> y su
    #   destino es una línea de un log de CI, no un documento. Esa diferencia
    #   estaba escondida y se hizo visible al escribir la resolución en F4.
    # · `acta` es de ORIGEN y SÍ es artefacto: el ARQUITECTO la publica como
    #   cualquier otro documento, y su locator es un `code` (`arquitecto-031`).
    #
    # Por eso deja de derivarse de DERIVED_KINDS. Derivada, `acta` se habría
    # quedado fuera y `Citations::Resolve` habría devuelto `nil` SIN ERROR: la
    # cita parsea y no resuelve contra nada, que es la peor forma de fallar.
    #
    # Y la salida fácil —meter `acta` en DERIVED_KINDS «para que resuelva»— es
    # peor: `Citations::DerivedRatio` contaría las decisiones de una persona como
    # material que el sistema se inventó a sí mismo, y movería el umbral de
    # deriva de MORFEO sin que nada se pusiera rojo.
    ARTIFACT_KINDS = %w[spec dod pkg close acta].freeze

    # Las piezas se declaran como CADENAS, no como Regexp, porque de ellas se
    # construyen dos cosas que no pueden divergir: los patrones de Ruby y el
    # `pattern` del contrato JSON Schema. Ver SCHEMA_PATTERN.
    REPOSITORY = "(?<repository>[a-z0-9]+(?:-[a-z0-9]+)*)"
    PATH       = '(?<path>[\w./-]+)'
    SLUG       = "(?<slug>[a-z0-9]+(?:[-.][a-z0-9]+)*)"
    DATE       = '(?<date>\d{4}-\d{2}-\d{2})'
    # Las notas humanas llevan iniciales de autor: 2026-05-08-ap
    #
    # Y, desde la enmienda del 26 de agosto, un sufijo ordinal ANIDADO dentro
    # del autor para cuando hay más de una nota del mismo autor el mismo día:
    # 2026-08-17-ap-2. El 1 no se usa; la primera nota del día no lleva sufijo.
    #
    # ⚠ ANIDADO Y NO SUELTO, y es la parte que no se puede perder. Suelto,
    # `note/2026-08-17-antonio` empezaría a parsear como fecha + sufijo SIN
    # autor, y Citations::Resolve#note sin autor cae a un LIKE que devuelve la
    # primera: resolvería a la nota equivocada, en silencio, dentro de un
    # artefacto que nadie puede reescribir. Anidado, `-antonio` sigue siendo
    # inválido, que es lo correcto.
    #
    # OJO: el grupo se llama `note_slug` y no `slug` por lo mismo que MEET_SLUG.
    # Si se llamara `slug`, Parse#locator_for lo devolvería como locator en vez
    # de la fecha y la resolución apuntaría al sitio equivocado sin que ningún
    # test se enterase.
    AUTHOR     = "(?:-(?<author>[a-z]{2,4})(?:-(?<note_slug>[a-z0-9]+(?:-[a-z0-9]+)*))?)?"
    # Las reuniones llevan sufijo opcional cuando hay más de una el mismo día.
    # OJO: se llama `meeting_slug` y no `slug` a propósito. Si se llamara `slug`,
    # Parse#locator_for lo devolvería como locator en lugar de la fecha, y la
    # resolución apuntaría al sitio equivocado sin que ningún test se enterase.
    MEET_SLUG  = "(?:-(?<meeting_slug>[a-z0-9]+(?:-[a-z0-9]+)*))?"
    ANCHOR     = '(?:#(?<anchor>L\d+|p\d+|§\d+|c\d+|deploy))?'
    # El ancla del acta va APARTE y no dentro de ANCHOR, que es lo que parecía
    # más corto. Metida ahí, `#abierta-1` habría pasado a ser válida también en
    # `doc`, `note`, `spec`, `dod` y las demás: siete formas nuevas aceptadas de
    # rebote por una enmienda que solo pedía una. El ensanchamiento se queda
    # confinado al tipo nuevo, que es lo que lo hace estrictamente aditivo.
    DECISION_ANCHOR = '(?:#(?<anchor>(?:abierta|cerrada|descartada)-\d+))?'
    SHA        = "(?<sha>[0-9a-f]{7})"
    CLOCK      = '(?<clock>[0-2]\d:[0-5]\d)'

    # Un cuerpo por forma de locator. Se prueban en orden y el primero que casa
    # de principio a fin, gana. Separarlos así es lo que permite que
    # "código sin repositorio" no cuele por la rama de slug.
    BODIES = [
      # code/<repo>:<path>[#anchor][@sha]  ·  verify/<repo>:<path>[#anchor][@sha]
      "(?<kind>code|verify)/#{REPOSITORY}:#{PATH}#{ANCHOR}(?:@#{SHA})?",
      # meet/<YYYY-MM-DD>[-slug][#anchor][@HH:MM]
      "(?<kind>meet)/#{DATE}#{MEET_SLUG}#{ANCHOR}(?:@#{CLOCK})?",
      # note/<YYYY-MM-DD>[-autor[-ordinal]][#anchor]
      "(?<kind>note)/#{DATE}#{AUTHOR}#{ANCHOR}",
      # doc|spec|dod|pkg|close/<slug>[#anchor]
      "(?<kind>doc|spec|dod|pkg|close)/#{SLUG}#{ANCHOR}",
      # acta/<slug>[#abierta-N|#cerrada-N|#descartada-N]
      #
      # Va el QUINTO y no antes: ningún cuerpo anterior contiene `acta`, así que
      # no puede ensombrecer a ninguno ni ser ensombrecido. Es la comprobación
      # de que la enmienda no toca lo ya escrito.
      "(?<kind>acta)/#{SLUG}#{DECISION_ANCHOR}"
    ].freeze

    PATTERNS = BODIES.map { |body| Regexp.new("\\A\\[src:#{body}\\]\\z") }.freeze

    # El mismo lenguaje, en la forma que entiende JSON Schema, para que el
    # contrato con el brain rechace exactamente lo que rechaza el parser.
    #
    # Se genera de BODIES en vez de escribirse a mano: escrito a mano, el
    # contrato aceptaba `[src:code/rates.ts#L40]` —código sin repositorio— y
    # nadie se enteraba. Los nombres de grupo se quitan porque repetirlos entre
    # alternativas es un error en ECMA-262.
    SCHEMA_PATTERN = begin
      alternatives = BODIES.map { |body| body.gsub(/\(\?<\w+>/, "(?:") }
      "^\\[src:(?:#{alternatives.join('|')})\\]$"
    end.freeze

    # El CÓDIGO de una nota humana —la fecha y el autor, sin el envoltorio de
    # cita—, en la forma que entiende JSON Schema. Es lo que `agent_run.v1.json`
    # valida en `human_notes[].code` al mandarle el contexto a un agente.
    #
    # Se genera aquí por exactamente la misma razón que SCHEMA_PATTERN: escrito
    # a mano en el contrato, se separó de la gramática sin que nadie se enterase.
    # Cuando P8 añadió el ordinal, el contrato seguía diciendo
    # `^\d{4}-\d{2}-\d{2}(-[a-z]{2,4})?$` y habría rechazado una nota que el
    # parser acepta — es decir, el contexto de un evolutivo con dos notas del
    # mismo autor el mismo día no habría salido de matrix.
    #
    # Se sincroniza con `bin/rails matrix:sync_contracts`, igual que el otro.
    NOTE_CODE_SCHEMA_PATTERN = "^#{DATE}#{AUTHOR}$".gsub(/\(\?<\w+>/, "(?:").freeze

    # Encuentra todas las citas dentro de un cuerpo markdown, en orden de
    # aparición. Deliberadamente laxo: captura cualquier cosa con forma de cita
    # para que la validación la haga Citations::Parse y una cita mal escrita se
    # detecte en vez de pasar inadvertida.
    #
    # NO usar para validar. Para eso está PATTERNS, y en el contrato,
    # SCHEMA_PATTERN.
    SCANNER = /\[src:[^\]\s]+\]/

    module_function

    def origin?(kind)  = ORIGIN_KINDS.include?(kind.to_s)
    def derived?(kind) = DERIVED_KINDS.include?(kind.to_s)

    # El nivel de procedencia. Ante conflicto entre niveles gana el ORIGEN;
    # esa regla se aplica en F4, pero el nivel se decide aquí.
    def level(kind)
      return :origin  if origin?(kind)
      return :derived if derived?(kind)

      raise ArgumentError, "tipo de fuente desconocido: #{kind.inspect}"
    end

    def repository_qualified?(kind) = REPOSITORY_QUALIFIED_KINDS.include?(kind.to_s)
  end
end
