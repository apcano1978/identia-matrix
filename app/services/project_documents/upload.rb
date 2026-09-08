# Subir un documento a un proyecto (F12 · B3).
#
# Es la primera vez que matrix acepta un fichero. La regla que lo permite no es
# «matrix ya guarda documentos», es **«un documento tiene un solo dueño, y se ve
# cuál es»**: por eso quien lo sube viaja con él y por eso el documento cuelga
# del proyecto y no de nadie más.
#
# ── Lo único que se rechaza es el tamaño ───────────────────────────────────
#
# Y es una decisión de la fase, no una omisión: **lo que no se sepa extraer se
# acepta y se marca sin cuerpo**, en vez de discutir formatos con quien sube. Un
# `.docx` que hoy no sabemos leer sigue siendo el documento que alguien tenía a
# mano, y guardarlo diciendo que no se pudo leer es más útil que negarlo en la
# puerta — el día que se sepa extraer, ahí está.
#
# El tope existe por lo de abajo, no por almacenamiento: el cuerpo extraído viaja
# entero al brain dentro de un POST.
class ProjectDocuments::Upload
  Refused = Class.new(StandardError)

  # 25 MB. Un acta en PDF con firmas escaneadas ronda los cinco; esto deja
  # margen sin admitir un volcado. Por encima, lo que se rompe no es la subida
  # sino lo que viene después: `ProjectDocuments::Extract` recorta a 200.000
  # caracteres, pero un csv de cien megas no tiene por qué caber en memoria para
  # llegar a ese recorte.
  MAX_BYTES = 25.megabytes

  def self.call(...) = new(...).call

  def initialize(project:, file:, uploader:, title: nil)
    @project = project
    @file = file
    @uploader = uploader
    @title = title
  end

  def call
    validate!

    document = create_document
    # ⚠ SE ENCOLA, no se extrae aquí. Una subida que espera a un PDF de
    # doscientas páginas es una subida que falla, y el estado «extrayendo texto»
    # que la pantalla enseña solo existe si esto ocurre fuera de la petición.
    ProjectDocuments::ExtractJob.perform_later(document.id)

    document
  end

  private

  attr_reader :project, :file, :uploader

  def validate!
    raise Refused, "no hay ningún fichero" if file.blank?

    return if file.size <= MAX_BYTES

    raise Refused,
          "#{filename} pesa #{helpers.number_to_human_size(file.size)} y el " \
          "tope son #{helpers.number_to_human_size(MAX_BYTES)}"
  end

  def create_document
    document = project.project_documents.new(
      uploaded_by_user: uploader, title: title, slug: slug)
    document.file.attach(file)
    document.save!
    document
  end

  # El nombre del fichero sin extensión, que es lo que quien sube reconoce. Se
  # puede pasar otro, y la pantalla de B5 lo hará.
  def title
    @title.presence || File.basename(filename, ".*").tr("_", " ").strip.presence ||
      "Documento sin nombre"
  end

  # Libre DENTRO DEL PROYECTO y también entre los documentos de platform de su
  # cliente: los dos se citan igual y `Citations::Resolve` no puede tener que
  # elegir. Lo resuelve `ProjectDocument.slug_for`, de B1.
  def slug = ProjectDocument.slug_for(title, project: project)

  def filename = file.original_filename.to_s

  def helpers = ActionController::Base.helpers
end
