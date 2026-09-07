# frozen_string_literal: true

module Artifacts
  # El front-matter de un artefacto. Congelado en F0, ENMENDADO EN F11 · B7b.
  #
  # Once campos. Va al principio del markdown, delimitado por ---, y viaja con
  # el fichero: quien saque un artefacto del bucket tiene que poder saber qué
  # es, de qué deriva y quién lo produjo, sin consultar la base de datos de
  # matrix.
  #
  #   ---
  #   key: artifacts://vivla/precio-festivos/dod-031/v2.md
  #   kind: dod
  #   code: dod-031
  #   version: 2
  #   initiative: precio-festivos
  #   project: vivla
  #   client: vivla
  #   produced_by: seraph/run-166
  #   produced_at: 2026-05-28T10:04:18+02:00
  #   derives_from: artifacts://vivla/precio-festivos/spec-031/v4.md
  #   checksum: sha256:6b86b273ff34fce…
  #   ---
  #
  # **LA ENMIENDA DE B7b, y por qué era inevitable.** El campo `client` nació
  # obligatorio porque en F0 no había forma de que un artefacto no tuviera
  # cliente detrás. Desde F11 sí la hay —un proyecto PROPIO no tiene ninguno— y
  # con `client` en `REQUIRED` publicar sobre él levantaba un `ArgumentError`:
  # matrix no podía escribir sobre sí misma.
  #
  # Se enmienda **añadiendo**, no reinterpretando. `project` entra obligatorio y
  # lleva el mismo string que el primer segmento de la clave; `client` se queda
  # donde estaba y pasa a opcional. Reutilizar `client` para meter dentro el
  # proyecto habría sido más corto y habría hecho ambiguos los artefactos ya
  # emitidos: los cuarenta y nueve que hay dicen `client: vivla` queriendo decir
  # el cliente, y tienen que seguir diciéndolo.
  #
  # No mueve nada de lo emitido: `parse` filtra por `FIELDS`, así que un
  # artefacto viejo se lee igual y sale sin `project`; y el checksum es del
  # CUERPO —no del fichero—, así que la cabecera puede crecer sin que ninguna
  # clave ni ninguna verificación cambie.
  #
  # `derives_from` es lo que ata la cadena de procedencia: el DoD deriva de la
  # spec, el informe de verificación del DoD, el cierre de todo lo anterior. Un
  # artefacto de origen (el dossier de TANK) lo lleva a nil.
  module FrontMatter
    FIELDS = %i[
      key
      kind
      code
      version
      initiative
      project
      client
      produced_by
      produced_at
      derives_from
      checksum
    ].freeze

    # Los que no pueden faltar.
    #
    # `derives_from` puede: el dossier de TANK no deriva de nada, arranca la
    # cadena. Y `client` puede desde B7b: un proyecto propio no tiene ninguno,
    # y exigirlo impedía que matrix publicara sobre su propio trabajo. Quién es
    # el dueño no se pierde por eso — lo dice `project`, que sí es obligatorio.
    OPTIONAL = %i[derives_from client].freeze
    REQUIRED = (FIELDS - OPTIONAL).freeze

    DELIMITER = "---"

    module_function

    def build(key:, kind:, code:, version:, initiative:, project:, produced_by:, produced_at:, checksum:, client: nil, derives_from: nil)
      {
        key: key,
        kind: kind.to_s,
        code: code,
        version: Integer(version),
        initiative: initiative,
        project: project,
        client: client,
        produced_by: produced_by,
        produced_at: produced_at.iso8601,
        derives_from: derives_from,
        checksum: checksum
      }
    end

    # Antepone el front-matter al cuerpo. El resultado es lo que se guarda.
    def render(attributes, body)
      validate!(attributes)

      yaml = FIELDS.map { |field| "#{field}: #{serialize(attributes[field])}" }.join("\n")

      "#{DELIMITER}\n#{yaml}\n#{DELIMITER}\n\n#{body.to_s.lstrip}"
    end

    # Separa el front-matter del cuerpo. Devuelve [atributos, cuerpo].
    # Si el documento no lo lleva, devuelve [{}, documento] — no revienta:
    # el cuerpo sigue siendo legible aunque la cabecera falte.
    def parse(document)
      match = /\A#{DELIMITER}\n(?<yaml>.*?)\n#{DELIMITER}\n(?<body>.*)\z/m.match(document.to_s)
      return [ {}, document.to_s ] if match.nil?

      attributes = match[:yaml].each_line.filter_map do |line|
        field, _, value = line.chomp.partition(": ")
        next unless FIELDS.include?(field.to_sym)

        [ field.to_sym, deserialize(field.to_sym, value) ]
      end.to_h

      [ attributes, match[:body].lstrip ]
    end

    def validate!(attributes)
      missing = REQUIRED.reject { |field| attributes[field].present? }
      return if missing.empty?

      raise ArgumentError, "faltan campos obligatorios en el front-matter: #{missing.join(', ')}"
    end

    def checksum_for(body) = "sha256:#{Digest::SHA256.hexdigest(body.to_s)}"

    def serialize(value) = value.nil? ? "~" : value.to_s

    def deserialize(field, value)
      return nil if value == "~" || value.empty?
      return Integer(value, 10) if field == :version

      value
    end
  end
end
