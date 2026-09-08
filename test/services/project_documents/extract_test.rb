# frozen_string_literal: true

require "test_helper"

# Sacar el texto de un documento subido. Lo que se prueba aquí son **los cuatro
# finales**, porque tres de ellos dejan el documento sin cuerpo y no son lo
# mismo: uno es un fichero que no sabemos leer, otro un PDF escaneado —que es un
# caso perfectamente legítimo— y el tercero un fichero roto.
#
# Los PDF son fixtures de verdad, los mismos que identia-platform lleva usando
# desde F5: un texto inventado a mano no ejercita `pdf-reader`.
class ProjectDocuments::ExtractTest < ActiveSupport::TestCase
  # ── Lo que sí se sabe leer ────────────────────────────────────────────────

  test "un markdown sale entero y deja el documento citable" do
    document = extract(content: "# Arranque\n\nLo que hay que hacer.",
                       filename: "nota.md", content_type: "text/markdown")

    assert_equal "# Arranque\n\nLo que hay que hacer.", document.body
    assert_predicate document, :citable?
    assert_predicate document, :extracted?
    assert_nil document.extraction_error
  end

  # Tal cual, sin interpretar columnas: lo que se cita es el texto.
  test "un csv va tal cual, sin interpretar columnas" do
    csv = "repositorio,commit\nbooking-core,4f2a9c1\n"
    document = extract(content: csv, filename: "repos.csv", content_type: "text/csv")

    assert_equal csv, document.body
  end

  test "y un pdf con capa de texto también" do
    document = extract_fixture("con-texto.pdf")

    assert_predicate document, :citable?
    assert_includes document.body, "Acta de precios"
    assert_includes document.body, "sube un 4 %"
  end

  # ⚠ EL TEST QUE SIN `scrub` REVIENTA EN POSTGRES. `download` devuelve
  # ASCII-8BIT, y un csv exportado en Latin-1 trae bytes que no son UTF-8
  # válido: la escritura falla y el documento se queda sin cuerpo por un motivo
  # que no es el suyo.
  test "un fichero mal codificado se guarda igual, sin bytes inválidos" do
    latin1 = "concepto;importe\nreunión;100\n".encode("ISO-8859-1")
    document = extract(content: latin1, filename: "gastos.csv",
                       content_type: "text/csv")

    assert_predicate document, :citable?
    assert_predicate document.body, :valid_encoding?
    assert_includes document.body, "importe"
  end

  # Un navegador manda `application/octet-stream` para un `.md` más veces de las
  # que parece. Rechazarlo por eso sería castigar al fichero por el navegador.
  test "y si el navegador no sabe qué tipo es, manda la extensión" do
    document = extract(content: "# Algo", filename: "nota.md",
                       content_type: "application/octet-stream")

    assert_equal "# Algo", document.body
  end

  # ── Los tres finales sin cuerpo, que no son el mismo ──────────────────────

  # NO es un fallo: un PDF escaneado sin OCR es un caso real, y decirlo es más
  # honesto que fingir un cuerpo vacío.
  test "un pdf escaneado se queda sin cuerpo, y dice que es eso" do
    document = extract_fixture("escaneado.pdf")

    assert_nil document.body
    refute_predicate document, :citable?
    assert_match "escaneado", document.extraction_error
  end

  test "uno roto también, pero nombrando la excepción" do
    document = extract_fixture("roto.pdf")

    assert_nil document.body
    assert_match(/PDF::Reader|MalformedPDF/, document.extraction_error,
                 "el error tiene que decir qué pasó: es lo que distingue un " \
                 "fichero roto de uno escaneado")
  end

  test "y un formato que no sabemos leer se acepta y se marca" do
    document = extract(content: "PK\x03\x04binario", filename: "cosas.zip",
                       content_type: "application/zip")

    assert_nil document.body
    assert_match "formato no soportado", document.extraction_error
    assert_match "application/zip", document.extraction_error
  end

  # ⚠ `extracted_at` se pone en los CUATRO finales, también sin cuerpo:
  # significa «se intentó y terminó». Sin eso, un PDF escaneado se quedaría para
  # siempre en el estado de «extrayendo».
  test "los cuatro finales terminan, aunque tres se queden sin cuerpo" do
    [ extract_fixture("escaneado.pdf"), extract_fixture("roto.pdf"),
      extract(content: "x", filename: "c.zip", content_type: "application/zip"),
      extract(content: "# Sí", filename: "n.md", content_type: "text/markdown") ]
      .each do |document|
      assert_predicate document, :extracted?,
                       "sin `extracted_at` se queda con la barra girando"
    end
  end

  # ── El tope ───────────────────────────────────────────────────────────────

  # El mismo que platform recorta ANTES de mandar un cuerpo a matrix
  # (`Internal::VersionBody::LIMIT`). Sin él, un csv de 25 MB serían 25 MB de
  # texto dentro de un POST al brain.
  test "un texto enorme se recorta, y el propio cuerpo lo dice" do
    largo = "a" * (ProjectDocuments::Extract::MAX_CHARS + 5_000)
    document = extract(content: largo, filename: "volcado.txt",
                       content_type: "text/plain")

    assert_equal ProjectDocuments::Extract::MAX_CHARS, document.body.length
    assert document.body.end_with?(ProjectDocuments::Extract::OMISSION),
           "la marca va DENTRO del texto: sin ella nadie sabe que falta algo"
  end

  test "y uno que cabe no se toca" do
    document = extract(content: "corto", filename: "n.txt",
                       content_type: "text/plain")

    assert_equal "corto", document.body
  end

  # ── El caso raro ──────────────────────────────────────────────────────────

  test "un documento sin fichero adjunto no revienta: lo dice" do
    document = ProjectDocument.create!(
      project: build_own_project, uploaded_by_user: build_platform_user,
      title: "Sin fichero", slug: "sin-fichero")

    ProjectDocuments::Extract.call(document)

    assert_nil document.reload.body
    assert_match "no tiene fichero", document.extraction_error
  end

  private
    def extract(content:, filename:, content_type:)
      document = build_project_document(slug: "documento-#{SecureRandom.hex(3)}",
                                        content: content, filename: filename,
                                        content_type: content_type)
      ProjectDocuments::Extract.call(document)
      document.reload
    end

    def extract_fixture(name)
      document = build_project_document(
        slug: name.sub(/\.pdf\z/, ""),
        content: Rails.root.join("test/fixtures/files", name).binread,
        filename: name, content_type: "application/pdf")
      ProjectDocuments::Extract.call(document)
      document.reload
    end
end
