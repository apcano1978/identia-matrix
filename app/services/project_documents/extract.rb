# frozen_string_literal: true

require "pdf/reader"

module ProjectDocuments
  # Sacar el texto de un documento subido y dejarlo en su fila.
  #
  # **Lo que se cita es el TEXTO, no el fichero.** El PDF, el markdown y el csv
  # son envases; lo que un agente lee y lo que una cita señala es lo de dentro.
  # Sin cuerpo un documento no es citable —`ProjectDocument#citable?`— y
  # `Runtime::Request#sources_of` ya lo filtra, así que esto es lo que convierte
  # una subida en una fuente de verdad.
  #
  # ── Por qué se extrae aquí y no en platform ────────────────────────────────
  #
  # `Attachments::ExtractText` de identia-platform lleva desde F5 haciendo esto,
  # y su comentario dice *«la extracción vive en platform, que es donde está el
  # binario; así matrix nunca toca un origen»*. Eso sigue siendo cierto **de los
  # documentos de platform**. Un documento subido a matrix no es un origen ajeno:
  # es un fichero que matrix guarda, y leerlo es leer lo suyo. Pedírselo a
  # platform ataría un proyecto PROPIO a un servicio que no le corresponde.
  #
  # La forma sí se copia de allí, con sus razones, porque está probada contra
  # ficheros reales.
  #
  # ── Los cuatro finales ─────────────────────────────────────────────────────
  #
  #   soportado y con texto   body · extracted_at · sin error
  #   soportado y sin texto   extracted_at · error explicando que no lo trae
  #   formato no soportado    extracted_at · error nombrando el tipo
  #   PDF roto o cifrado      extracted_at · error nombrando la excepción
  #
  # ⚠ `extracted_at` se pone SIEMPRE, también cuando no hay cuerpo: significa
  # «se intentó y terminó», que es lo que distingue *extrayendo* de *sin cuerpo
  # extraído*. Sin eso, un PDF escaneado se quedaría para siempre con la barra
  # girando en pantalla.
  module Extract
    TEXT_TYPES = %w[text/markdown text/x-markdown text/plain text/csv
                    application/csv].freeze
    PDF_TYPE = "application/pdf"

    # El respaldo cuando el navegador no sabe qué tipo mandar. Un `.md` llega
    # como `application/octet-stream` más veces de las que parece, y rechazarlo
    # por eso sería castigar al fichero por el navegador.
    TEXT_EXTENSIONS = %w[.md .markdown .txt .csv].freeze
    PDF_EXTENSION = ".pdf"

    # EL MISMO TOPE QUE PLATFORM, y no es un límite inventado.
    #
    # `Internal::VersionBody::LIMIT` recorta a 200.000 el cuerpo de un documento
    # ANTES de mandárselo a matrix, así que todo lo que hoy viaja a un agente ya
    # viene por debajo. Sin tope, un documento subido podría ser cien veces mayor
    # que cualquier cosa que platform haya mandado nunca — y con 25 MB de tope de
    # subida, un csv de 25 MB es 25 MB de texto dentro de un POST al brain.
    #
    # La marca va DENTRO del texto, como en platform: el cuerpo dice de sí mismo
    # que está recortado, sin necesidad de una columna que pueda discrepar.
    MAX_CHARS = 200_000
    OMISSION = "\n\n[… recortado …]"

    # Un PDF con capa de texto pero casi vacía —una portada escaneada con el
    # número de página— es a efectos prácticos un escaneado. El umbral es bajo a
    # propósito: distingue «nada» de «algo», no juzga la calidad. Copiado de
    # `Attachments::ExtractText::MIN_CHARS` de platform.
    MIN_PDF_CHARS = 20

    module_function

    def call(document)
      texto, error = extract(document)

      document.update!(body: texto.presence, extracted_at: Time.current,
                       extraction_error: error)
      document
    end

    def extract(document)
      blob = document.file.blob
      return [ nil, "el documento no tiene fichero adjunto" ] if blob.blank?

      case format_of(blob)
      when :text then [ trim(plain_text(blob)), nil ]
      when :pdf then from_pdf(blob)
      else
        [ nil, "formato no soportado: #{blob.content_type}" ]
      end
    end

    # Por el `content_type` y, si no dice nada útil, por la extensión.
    def format_of(blob)
      extension = File.extname(blob.filename.to_s).downcase

      return :text if TEXT_TYPES.include?(blob.content_type) ||
                      TEXT_EXTENSIONS.include?(extension)
      return :pdf if blob.content_type == PDF_TYPE || extension == PDF_EXTENSION

      :unsupported
    end

    # ⚠ `scrub` no es cosmético. `download` devuelve ASCII-8BIT, y un csv
    # exportado en Latin-1 trae bytes que no son UTF-8 válido: Postgres rechaza
    # la escritura y el documento se queda sin cuerpo por un motivo que no es el
    # suyo. El csv va TAL CUAL, sin interpretar columnas — lo que se cita es el
    # texto.
    def plain_text(blob) = blob.download.force_encoding("UTF-8").scrub

    def from_pdf(blob)
      texto = PDF::Reader.new(StringIO.new(blob.download))
                         .pages.map { |page| page.text.to_s }
                         .join("\n\n").squeeze("\n").strip

      if texto.length < MIN_PDF_CHARS
        # NO es un fallo: un PDF escaneado sin OCR es un caso real, y decirlo es
        # más honesto que fingir un cuerpo vacío. Se guarda aparte de lo que sí
        # merece reintento.
        return [ nil, "el PDF no trae capa de texto: probablemente esté escaneado" ]
      end

      [ trim(texto), nil ]
    rescue StandardError => error
      # Roto, cifrado o con una función que la gema no soporta. Este sí es un
      # fallo, y por eso nombra la excepción: es lo que hace falta para saber si
      # merece la pena reintentarlo.
      [ nil, "#{error.class}: #{error.message}".truncate(255) ]
    end

    def trim(texto) = texto.truncate(MAX_CHARS, omission: OMISSION)
  end
end
