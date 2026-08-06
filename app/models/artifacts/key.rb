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
      close: "close"            # LINK · cierre documental
    }.freeze

    KINDS = PREFIXES.keys.freeze

    # Tipos cuyo número lo hereda del evolutivo. `pkg` es el único que no.
    INITIATIVE_NUMBERED = (KINDS - [ :pkg ]).freeze

    # Tipos que pueden llevar sufijo de ronda: verify-031-r2 es el informe del
    # segundo ciclo de QA. Sin el sufijo, el segundo informe pisaría al primero
    # y perderíamos justo el historial que el sistema existe para conservar.
    ROUNDED = [ :verify ].freeze

    SLUG    = /[a-z0-9]+(?:-[a-z0-9]+)*/
    PATTERN = %r{
      \A#{SCHEME}://
      (?<client>#{SLUG})/
      (?<initiative>ev-\d{3,})/
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
