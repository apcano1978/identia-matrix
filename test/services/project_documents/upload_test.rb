# frozen_string_literal: true

require "test_helper"

# Subir un documento. Lo que se prueba aquí es **qué se rechaza y qué no**: la
# decisión de la fase es que el tamaño sea lo único que cierra la puerta, y que
# lo que no se sepa extraer entre igual y se marque sin cuerpo.
class ProjectDocuments::UploadTest < ActiveSupport::TestCase
  setup do
    @project = build_own_project(slug: "identia-interno")
    @uploader = build_platform_user
  end

  test "guarda el documento, con su dueño y en su propio almacén" do
    document = upload("acta-precios.md", "# Acta\n\nLo acordado.")

    assert_equal @project, document.project
    assert_equal @uploader, document.uploaded_by_user
    assert_equal "documents", document.file.blob.service_name
  end

  # El nombre del fichero sin extensión es lo que quien sube reconoce. El slug
  # sale de ahí, y sale libre entre las dos tablas — eso lo resuelve B1.
  test "el título sale del nombre del fichero y el slug del título" do
    document = upload("acta_de_precios.md", "# Acta")

    assert_equal "acta de precios", document.title
    assert_equal "acta-de-precios", document.slug
  end

  test "y no choca con un documento de platform del mismo cliente" do
    client = build_client(slug: "vivla")
    build_document(client: client, slug: "acta-precios")
    proyecto = project_for(client)

    document = ProjectDocuments::Upload.call(
      project: proyecto, uploader: @uploader,
      file: fixture_file_upload_from("acta precios.md", "# Acta"))

    assert_equal "acta-precios-2", document.slug
  end

  # ⚠ LA PROPIEDAD DEL BLOQUE: se encola, no se extrae en la petición. Una
  # subida que espera a un PDF de doscientas páginas es una subida que falla.
  test "encola la extracción en vez de hacerla" do
    document = upload("nota.md", "# Nota")

    # Al volver, el cuerpo todavía no está: lo pondrá el job.
    assert_nil document.body
    refute_predicate document, :extracted?
  end

  test "y el servicio no llama al extractor por su cuenta" do
    fuente = Rails.root.join("app/services/project_documents/upload.rb").read
                  .gsub(/^\s*#.*$/, "")

    assert_match(/ExtractJob\.perform_later/, fuente)
    assert_no_match(/Extract\.call/, fuente,
                    "extraer dentro de la petición es lo que este bloque evita")
  end

  # ── Lo único que se rechaza ───────────────────────────────────────────────

  test "un fichero de más de 25 MB no entra, y lo dice con su tamaño" do
    grande = fixture_file_upload_from("volcado.csv",
                                      "a" * (ProjectDocuments::Upload::MAX_BYTES + 1))

    error = assert_raises(ProjectDocuments::Upload::Refused) do
      ProjectDocuments::Upload.call(project: @project, uploader: @uploader,
                                    file: grande)
    end

    assert_match "volcado.csv", error.message
    assert_match "25 MB", error.message
    assert_equal 0, @project.project_documents.count
  end

  test "sin fichero tampoco se escribe nada" do
    assert_raises(ProjectDocuments::Upload::Refused) do
      ProjectDocuments::Upload.call(project: @project, uploader: @uploader,
                                    file: nil)
    end

    assert_equal 0, @project.project_documents.count
  end

  # Y ES LO ÚNICO. Un `.docx` que hoy no sabemos leer sigue siendo el documento
  # que alguien tenía a mano: se acepta y B2 lo marca sin cuerpo, en vez de
  # discutir formatos en la puerta.
  test "pero un formato que no sabemos leer entra igual" do
    document = upload("propuesta.docx", "PK binario",
                      type: "application/vnd.openxmlformats-officedocument")

    assert_predicate document, :persisted?
    assert_equal "propuesta", document.title
  end

  private
    def upload(filename, content, type: "text/markdown")
      ProjectDocuments::Upload.call(
        project: @project, uploader: @uploader,
        file: fixture_file_upload_from(filename, content, type))
    end

    # Un `UploadedFile` de verdad, que es lo que llega de un formulario: tiene
    # `original_filename` y `size`, y el servicio usa los dos.
    def fixture_file_upload_from(filename, content, type = "text/markdown")
      path = Rails.root.join("tmp", "subida-#{SecureRandom.hex(4)}")
      path.binwrite(content)

      Rack::Test::UploadedFile.new(path.to_s, type, original_filename: filename)
    end
end
