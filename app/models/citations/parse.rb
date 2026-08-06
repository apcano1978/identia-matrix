# frozen_string_literal: true

module Citations
  # Parsea una cita contra la gramática congelada en F0.
  #
  #   Citations::Parse.call("[src:code/booking-core:rates.ts#L40@4f2a9c1]")
  #   # => #<Citations::Reference kind="code" repository="booking-core" …>
  #
  #   Citations::Parse.call("[src:code/rates.ts#L40]")
  #   # => nil   (código sin calificador de repositorio)
  #
  # `call` devuelve nil ante una cita mal formada; `call!` levanta. La versión
  # tolerante es la que usa el escaneo de un artefacto —una cita rota no debe
  # tumbar el render de una spec— y la estricta es la que usan las validaciones.
  class Parse
    class InvalidCitation < StandardError; end

    def self.call(raw)  = new(raw).call
    def self.call!(raw) = new(raw).call!

    # Extrae todas las citas de un cuerpo markdown, en orden de aparición.
    # Devuelve [referencias_válidas, crudos_inválidos] para que quien llame
    # decida qué hacer con lo que no parsea.
    def self.scan(body)
      valid = []
      invalid = []

      body.to_s.scan(Grammar::SCANNER).each do |raw|
        reference = call(raw)
        reference ? valid << reference : invalid << raw
      end

      [ valid, invalid ]
    end

    def initialize(raw)
      @raw = raw.to_s.strip
    end

    def call
      match = Grammar::PATTERNS.lazy.filter_map { |pattern| pattern.match(@raw) }.first
      return nil if match.nil?

      build(match)
    end

    def call!
      call || raise(InvalidCitation, "cita mal formada: #{@raw.inspect}")
    end

    private

    def build(match)
      names = match.names

      Reference.new(
        raw: @raw,
        kind: match[:kind],
        repository: capture(match, names, "repository"),
        locator: locator_for(match, names),
        anchor: capture(match, names, "anchor"),
        commit_sha: capture(match, names, "sha"),
        clock: capture(match, names, "clock"),
        author: capture(match, names, "author"),
        meeting_slug: capture(match, names, "meeting_slug")
      )
    end

    # El locator es lo que identifica la fuente dentro de su tipo: la ruta del
    # fichero, el slug del documento o la fecha de la reunión.
    #
    # El sufijo de reunión NO entra aquí: es un desambiguador, no la identidad.
    # Una cita de reunión resuelve por fecha, y el sufijo solo elige entre las
    # de ese día. Por eso el grupo se llama `meeting_slug` y no `slug`.
    def locator_for(match, names)
      capture(match, names, "path") ||
        capture(match, names, "slug") ||
        capture(match, names, "date")
    end

    # Cada patrón declara sus propios grupos, así que preguntar por uno que ese
    # patrón no define levantaría IndexError.
    def capture(match, names, name)
      match[name] if names.include?(name)
    end
  end
end
