# frozen_string_literal: true

module Artifacts
  # Las claves de artefacto. CONGELADAS EN F0 — como la gramática de citas.
  #
  #   artifacts://{cliente}/{evolutivo}/{codigo}/v{n}.md
  #   artifacts://vivla/ev-031/dod-031/v2.md
  #
  # Tres decisiones que hay que acertar a la primera, porque una clave emitida
  # no se puede reescribir:
  #
  # 1. EL REPOSITORIO NO VA EN LA RUTA. Un artefacto pertenece al evolutivo, y
  #    un evolutivo puede abarcar varios repositorios. Meter el repositorio
  #    obligaría a elegir uno, y ev-031 toca tres.
  #
  # 2. EL SEGMENTO DE CLIENTE ES UN SLUG CONGELADO, propiedad de matrix. Se fija
  #    en la primera sincronización desde platform y no se vuelve a tocar aunque
  #    allí renombren al cliente. Sin esto, un renombrado en platform rompería
  #    todas las claves ya emitidas.
  #
  # 3. LA NUMERACIÓN DEPENDE DEL TIPO. spec, dod, verify, guide y close heredan
  #    el número del evolutivo (ev-031 → spec-031). pkg tiene secuencia propia
  #    (ev-031 → PKG-045). La maqueta lo confirma en las dos direcciones.
  module Key
    SCHEME = "artifacts"

    # Prefijo de código por tipo de artefacto. No coincide siempre con el nombre
    # del tipo: la guía se llama "guia-pruebas" porque así se la nombra en la
    # interfaz, y la interfaz manda sobre el nombre interno.
    PREFIXES = {
      dossier: "dossier",       # TANK · contexto
      spec: "spec",             # NEO
      dod: "dod",               # SERAPH · definition of done
      pkg: "pkg",               # TRINITY · paquete de trabajo
      verify: "verify",         # SERAPH · informe de verificación
      guide: "guia-pruebas",    # SERAPH · guía de pruebas manuales
      close: "close",           # LINK · cierre documental
      # ARQUITECTO · el acta de decisiones de la etapa 1. ANEXADO AL FINAL en
      # F11, y ahí tiene que quedarse: de estas claves sale KINDS, y de KINDS el
      # enum `Artifact#kind`, que es una columna entera y por tanto posicional.
      #
      # El prefijo no coincide con el nombre del tipo, igual que en `guide`:
      # ev-031 produce `arquitecto-031`, que es lo que nombra la cita.
      acta: "arquitecto"
    }.freeze

    KINDS = PREFIXES.keys.freeze

    # ⚠ EL ORDEN DE `KINDS` NO ES EL DEL PIPELINE, y desde B8 dejan de coincidir.
    #
    # `KINDS` es orden de ALMACENAMIENTO: de él sale el enum `Artifact#kind`, que
    # es una columna entera, así que lo nuevo se anexa al final y nada se puede
    # intercalar. `acta` entró la última **y trabaja la primera** — la escribe el
    # ARQUITECTO en la etapa 1.
    #
    # Los dos órdenes fueron el mismo durante siete tipos, y esa coincidencia se
    # coló en el visor de artefactos, que ordenaba por `KINDS.index` para abrir
    # por el más avanzado. Con el acta anexada, abría por ella: el primero del
    # flujo presentado como el último. Es la misma lección que `AgentRun#agent`,
    # donde el ARQUITECTO es el 6 y actúa antes que el 0.
    PIPELINE_ORDER = %i[acta dossier spec dod pkg verify guide close].freeze

    # De menor a mayor avance. Un tipo que no esté en la lista va al final, para
    # que añadir uno sin declarar aquí no lo esconda en silencio.
    def self.pipeline_position(kind)
      PIPELINE_ORDER.index(kind.to_sym) || PIPELINE_ORDER.size
    end

    # Tipos cuyo número lo hereda del evolutivo. `pkg` es el único que no.
    INITIATIVE_NUMBERED = (KINDS - [ :pkg ]).freeze

    # Tipos que pueden llevar sufijo de ronda: verify-031-r2 es el informe del
    # segundo ciclo de QA. Sin el sufijo, el segundo informe pisaría al primero
    # y perderíamos justo el historial que el sistema existe para conservar.
    ROUNDED = [ :verify ].freeze

    SLUG    = /[a-z0-9]+(?:-[a-z0-9]+)*/
    # El segundo segmento es un SLUG, no `ev-\d{3,}`.
    #
    # ES UN ENSANCHAMIENTO, NO UNA RUPTURA, y esa es toda la razón por la que
    # una clave congelada en F0 se puede tocar en F11: `ev-031` casa con SLUG,
    # así que ninguna de las claves ya emitidas deja de parsear. Lo que antes
    # era válido lo sigue siendo — la misma clase de enmienda que las aditivas
    # de los contratos, y la contraria a las que cerraron la ventana.
    #
    # Lo que NO cambia es de dónde sale el NÚMERO del código de un artefacto:
    # de `initiative.code`, nunca de este segmento. Ver number_from_initiative.
    PATTERN = %r{
      \A#{SCHEME}://
      (?<client>#{SLUG})/
      (?<initiative>#{SLUG})/
      (?<code>#{SLUG})/
      v(?<version>\d+)\.md\z
    }x

    Parsed = Data.define(:client, :initiative, :code, :version)

    module_function

    # El código de un artefacto: "dod-031", "verify-031-r2", "pkg-045".
    def code(kind:, number:, round: nil)
      kind = normalize_kind(kind)
      prefix = PREFIXES.fetch(kind)
      base = "#{prefix}-#{format('%03d', Integer(number))}"

      return base if round.blank?

      unless ROUNDED.include?(kind)
        raise ArgumentError, "el tipo #{kind} no admite sufijo de ronda"
      end

      "#{base}-r#{Integer(round)}"
    end

    # La clave completa. `version` empieza en 1 y solo avanza: un artefacto
    # nunca se sobrescribe, se publica una versión nueva.
    def build(client:, initiative:, code:, version:)
      version = Integer(version)
      raise ArgumentError, "la versión empieza en 1" if version < 1

      "#{SCHEME}://#{client}/#{initiative}/#{code}/v#{version}.md"
    end

    # Atajo para el caso normal: construir la clave a partir del tipo y el
    # número, sin componer el código a mano.
    def for(client:, initiative:, kind:, number:, version:, round: nil)
      build(
        client: client,
        initiative: initiative,
        code: code(kind: kind, number: number, round: round),
        version: version
      )
    end

    # El número que le toca a un artefacto según su tipo. Los que heredan del
    # evolutivo lo sacan de su código (ev-031 → 31); `pkg` lo pide a su
    # secuencia, que en F0 todavía no existe.
    #
    # ⚠ SU ENTRADA ES UN `code`, NUNCA EL SEGMENTO DE UNA CLAVE. Desde que el
    # segundo segmento es un SLUG, los dos se parecen y son cosas distintas: el
    # segmento puede ser `precio-festivos` y de ahí no sale ningún número. Sigue
    # exigiendo `ev-NNN` a propósito — el día que alguien le pase un
    # `Parsed#initiative`, revienta en vez de inventarse un número.
    def number_from_initiative(initiative_code)
      match = /\Aev-(?<number>\d{3,})\z/.match(initiative_code.to_s)
      raise ArgumentError, "código de evolutivo inválido: #{initiative_code.inspect}" if match.nil?

      Integer(match[:number], 10)
    end

    def parse(key)
      match = PATTERN.match(key.to_s)
      return nil if match.nil?

      Parsed.new(
        client: match[:client],
        initiative: match[:initiative],
        code: match[:code],
        version: Integer(match[:version], 10)
      )
    end

    def parse!(key)
      parse(key) || raise(ArgumentError, "clave de artefacto inválida: #{key.inspect}")
    end

    def valid?(key) = !parse(key).nil?

    # La raíz del evolutivo, que es lo que la maqueta enseña en el nodo 12 del
    # pipeline: "artifacts://vivla/ev-009".
    def prefix_for(client:, initiative:)
      "#{SCHEME}://#{client}/#{initiative}"
    end

    def normalize_kind(kind)
      kind = kind.to_sym
      raise ArgumentError, "tipo de artefacto desconocido: #{kind.inspect}" unless KINDS.include?(kind)

      kind
    end
  end
end
