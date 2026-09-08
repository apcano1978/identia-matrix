require "test_helper"

# El slug va dentro de citas inmutables, así que lo que se afirma aquí no es que
# quede bonito: es que **parsee como cita**. Un slug que no case con la gramática
# de F0 convierte en no-parseable una referencia ya emitida dentro de un
# artefacto que nadie puede reescribir.
class Platform::SlugTest < ActiveSupport::TestCase
  include DomainBuilders

  # La comprobación de verdad: se construye la cita y se pasa por el parser real,
  # no por una expresión regular copiada aquí que podría divergir.
  def assert_citable(slug)
    assert Citations::Parse.call("[src:doc/#{slug}]"),
           "`#{slug}` no parsea como locator de documento"
    # El sufijo de reunión es el más estricto de los dos: no admite puntos.
    assert Citations::Parse.call("[src:meet/2026-05-02-#{slug}]"),
           "`#{slug}` no parsea como sufijo de reunión"
  end

  test "un título normal da un slug citable" do
    slug = Platform::Slug.derive(Platform::Document,
                                 "Acta · unificación del precio de festivos",
                                 fallback: "documento-1")

    assert_equal "acta-unificacion-del-precio-de-festivos", slug
    assert_citable slug
  end

  test "los acentos, los signos y los números salen citables" do
    [ "SLA 99.9 % de disponibilidad", "Reunión #3 — precios",
      "Añadir soporte para ñ y ü", "2026: el año", "C++ y C#" ].each do |title|
      assert_citable Platform::Slug.derive(Platform::Document, title, fallback: "doc-1")
    end
  end

  test "un título que no deja nada cae al respaldo, y el respaldo también es citable" do
    # «···» parameteriza a cadena vacía, y la columna es NOT NULL. Es el único
    # caso que `parameterize` no resuelve solo.
    [ "···", "   ", "!!!", "" ].each do |title|
      slug = Platform::Slug.derive(Platform::Document, title, fallback: "document-5001")

      assert_equal "document-5001", slug
      assert_citable slug
    end
  end

  test "dos títulos iguales no colisionan, y el sufijo empieza en 2" do
    client = build_client

    primero = crear_documento(client, "Acta de precios")
    assert_equal "acta-de-precios", primero.slug

    segundo = crear_documento(client, "Acta de precios")
    tercero = crear_documento(client, "Acta de precios")

    assert_equal "acta-de-precios-2", segundo.slug
    assert_equal "acta-de-precios-3", tercero.slug
    [ segundo, tercero ].each { |doc| assert_citable doc.slug }
  end

  test "el sufijo es determinista: el mismo orden da el mismo resultado" do
    # Determinista por orden de primera sincronización. Renombrar
    # retroactivamente sería peor que un sufijo feo: rompería citas emitidas.
    client = build_client
    2.times { crear_documento(client, "Informe") }

    assert_equal %w[informe informe-2],
                 Platform::Document.order(:platform_id).pluck(:slug)
  end

  # ── `among`, la enmienda de F12 ───────────────────────────────────────────
  #
  # Un documento SUBIDO y uno de platform se citan igual —`[src:doc/…]`— y viven
  # en tablas distintas. Sin mirar las dos, dos documentos del mismo proyecto
  # podrían llamarse igual y `Citations::Resolve` tendría que elegir en silencio
  # entre ellos, dentro de una cita ya escrita en markdown inmutable.
  test "esquiva un nombre que ya usa OTRA tabla" do
    project = build_own_project
    build_project_document(project: project, slug: "informe")

    libre = Platform::Slug.derive(
      Platform::Document, "Informe", fallback: "doc",
      among: [ ProjectDocument.where(project_id: project.id) ])

    assert_equal "informe-2", libre
  end

  test "y sigue contando hasta encontrar uno libre en las dos" do
    project = build_own_project
    build_project_document(project: project, slug: "informe")
    build_project_document(project: project, slug: "informe-2")
    crear_documento(build_client, "Informe-3")

    libre = Platform::Slug.derive(
      Platform::Document, "Informe", fallback: "doc",
      among: [ ProjectDocument.where(project_id: project.id) ])

    assert_equal "informe-4", libre
  end

  # ADITIVO: los llamantes de hoy no lo pasan y no se enteran. Es la misma forma
  # que tuvo `scope:` al llegar en F11.
  test "sin `among` no cambia nada para quien no lo pasa" do
    client = build_client
    crear_documento(client, "Informe")
    build_project_document(project: build_own_project, slug: "informe")

    assert_equal "informe-2",
                 Platform::Slug.derive(Platform::Document, "Informe", fallback: "doc")
  end

  private

  def crear_documento(client, title)
    Platform::Record.writing do
      Platform::Document.create!(
        platform_id: next_platform_id, platform_client: client, title: title,
        slug: Platform::Slug.derive(Platform::Document, title, fallback: "doc"))
    end
  end
end
