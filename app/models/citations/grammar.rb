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
  #           <YYYY-MM-DD>    en meet y note, con sufijo opcional
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
  # ── Dos enmiendas, ambas ADITIVAS, del 5 de agosto de 2026 ──────────────
  #
  # 1. `close` como noveno tipo. Sin él TANK no podía citar la fuente al afirmar
  #    que un evolutivo revierte una decisión de otro, que es el valor central
  #    del sistema:  [src:close/close-002#§3]
  #
  # 2. Sufijo opcional en las reuniones, porque la fecha sola no distingue dos
  #    el mismo día. La forma corta sigue valiendo:
  #      [src:meet/2026-05-02@22:40]
  #      [src:meet/2026-05-02-unificacion-precio@22:40]
  #
  # Se pudieron hacer porque todavía no existe ningún artefacto real: solo el
  # seed, que se regenera. La ventana se cierra cuando el primer agente produzca
  # uno de verdad.
  module Grammar
    # Los nueve tipos de fuente. El nivel de procedencia NO se almacena: se
    # deriva de aquí. Un dato derivable no puede desincronizarse.
    ORIGIN_KINDS  = %w[code doc meet note].freeze
    DERIVED_KINDS = %w[spec dod verify pkg close].freeze
    KINDS = (ORIGIN_KINDS + DERIVED_KINDS).freeze

    # Los tipos que exigen calificador de repositorio en el locator.
    REPOSITORY_QUALIFIED_KINDS = %w[code verify].freeze

    # Los tipos cuyo locator es una fecha.
    DATED_KINDS = %w[meet note].freeze

    # Los tipos cuyo locator es el `code` de un artefacto. NO es lo mismo que
    # DERIVED_KINDS: `verify` también es derivado, pero su locator es
    # <repo>:<run> y su destino es una línea de un log de CI, no un documento.
    # Esa diferencia estaba escondida y se hizo visible al escribir la
    # resolución en F4.
    ARTIFACT_KINDS = (DERIVED_KINDS - REPOSITORY_QUALIFIED_KINDS).freeze

    # Las piezas se declaran como CADENAS, no como Regexp, porque de ellas se
    # construyen dos cosas que no pueden divergir: los patrones de Ruby y el
    # `pattern` del contrato JSON Schema. Ver SCHEMA_PATTERN.
    REPOSITORY = "(?<repository>[a-z0-9]+(?:-[a-z0-9]+)*)"
    PATH       = '(?<path>[\w./-]+)'
    SLUG       = "(?<slug>[a-z0-9]+(?:[-.][a-z0-9]+)*)"
    DATE       = '(?<date>\d{4}-\d{2}-\d{2})'
    # Las notas humanas llevan iniciales de autor: 2026-05-08-ap
    AUTHOR     = "(?:-(?<author>[a-z]{2,4}))?"
    # Las reuniones llevan sufijo opcional cuando hay más de una el mismo día.
    # OJO: se llama `meeting_slug` y no `slug` a propósito. Si se llamara `slug`,
    # Parse#locator_for lo devolvería como locator en lugar de la fecha, y la
    # resolución apuntaría al sitio equivocado sin que ningún test se enterase.
    MEET_SLUG  = "(?:-(?<meeting_slug>[a-z0-9]+(?:-[a-z0-9]+)*))?"
    ANCHOR     = '(?:#(?<anchor>L\d+|p\d+|§\d+|c\d+|deploy))?'
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
      # note/<YYYY-MM-DD>[-autor][#anchor]
      "(?<kind>note)/#{DATE}#{AUTHOR}#{ANCHOR}",
      # doc|spec|dod|pkg|close/<slug>[#anchor]
      "(?<kind>doc|spec|dod|pkg|close)/#{SLUG}#{ANCHOR}"
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
