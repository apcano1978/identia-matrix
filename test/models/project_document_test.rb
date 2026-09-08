require "test_helper"

# Un documento subido a un proyecto. Lo que se prueba aquí son las dos cosas de
# las que depende todo lo demás: **cómo se llama** —porque entra en citas que
# nadie puede reescribir— y **dónde viven sus bytes**, porque de eso depende que
# el latido de artefactos siga diciendo la verdad.
class ProjectDocumentTest < ActiveSupport::TestCase
  # ── El nombre ─────────────────────────────────────────────────────────────

  test "el slug se congela al crear, como el del proyecto y el del evolutivo" do
    document = build_project_document(slug: "acta-precios")

    assert_raises(ActiveRecord::ReadOnlyRecord) { document.update!(slug: "otra") }
    assert_equal "acta-precios", document.reload.slug
  end

  test "pero el título sí se puede cambiar: eso se lee, no se cita" do
    document = build_project_document(title: "Acta de precios")
    document.update!(title: "Acta de precios · v2")

    assert_equal "Acta de precios · v2", document.reload.title
  end

  test "dos documentos del mismo proyecto no comparten nombre" do
    project = build_own_project
    build_project_document(project: project, slug: "acta-precios")

    repetido = ProjectDocument.new(project: project, slug: "acta-precios",
                                   title: "Otra", uploaded_by_user: build_platform_user)

    refute_predicate repetido, :valid?
  end

  test "y dos proyectos distintos pueden llamar igual a los suyos" do
    primero = build_project_document(project: build_own_project, slug: "acta-precios")
    segundo = build_project_document(project: build_own_project, slug: "acta-precios")

    assert_equal "acta-precios", primero.slug
    assert_equal "acta-precios", segundo.slug
  end

  # LA REGLA DE LA FASE. Un documento subido y uno de platform se citan IGUAL
  # —`[src:doc/acta-precios]`— y `Citations::Resolve` los busca dentro del mismo
  # proyecto: si pudieran llamarse igual, tendría que elegir en silencio entre
  # ellos, dentro de una cita ya escrita.
  test "el nombre tampoco choca con uno de platform del mismo cliente" do
    client = build_client(slug: "vivla")
    build_document(client: client, slug: "acta-precios")

    # El título tiene que dar ESE slug: `parameterize` no quita preposiciones, y
    # «Acta de precios» daría `acta-de-precios`, que no chocaría con nada.
    derivado = ProjectDocument.slug_for("Acta precios", project: project_for(client))

    assert_equal "acta-precios-2", derivado
  end

  # Y al revés, que es la dirección que se olvida: una sincronización POSTERIOR
  # no puede crear la ambigüedad que el alta evitó. La cubre
  # `Platform::Projection#assign_slug`.
  test "ni uno de platform con uno ya subido" do
    client = build_client(slug: "vivla")
    build_project_document(project: project_for(client), slug: "acta-precios")

    fuente = Struct.new(:documents, :name).new(
      [ { platform_id: 9_001, title: "Acta precios",
          client_platform_id: client.platform_id } ], "fake")
    Platform::Projection.import(fuente, client: client, only: %i[documents])

    assert_equal "acta-precios-2",
                 Platform::Document.find_by!(platform_id: 9_001).slug
  end

  # El nombre que compone tiene que ser una cita que el parser acepte: si no, el
  # documento no se puede citar y media fase no sirve.
  test "la cita que compone la parsea la gramática de F0" do
    document = build_project_document(slug: "acta-precios")

    assert_equal "[src:doc/acta-precios]", document.citation

    valid, invalid = Citations::Parse.scan(document.citation)

    assert_empty invalid
    assert_equal "doc", valid.sole.kind
    assert_equal "acta-precios", valid.sole.locator
  end

  # ── El cuerpo y el retiro ─────────────────────────────────────────────────

  test "sin cuerpo extraído no es citable, y eso es un estado legítimo" do
    # Un PDF escaneado del que nadie sacó texto es un caso real. Decirlo es más
    # honesto que fingir un cuerpo vacío — la misma regla que Platform::Document.
    document = build_project_document(body: nil)

    refute_predicate document, :citable?
    refute_predicate document, :extracted?
  end

  test "con cuerpo sí" do
    assert_predicate build_project_document(body: "El texto."), :citable?
  end

  # ⚠ Retirar NO es borrar, y la diferencia se ve aquí: sale del ámbito de los
  # evolutivos nuevos y **sigue resolviendo en las citas ya emitidas**. Si
  # `citable?` cayera al retirarlo, un artefacto publicado hace meses pasaría a
  # citar algo que el sistema dice que no se puede citar.
  test "un retirado sale del ámbito nuevo y sigue siendo citable" do
    project = build_own_project
    vigente = build_project_document(project: project, body: "Uno.", slug: "uno")
    retirado = build_project_document(project: project, body: "Dos.", slug: "dos",
                                      retired_at: Time.current)

    assert_equal [ vigente ], project.project_documents.available.to_a
    assert_equal [ retirado ], project.project_documents.retired.to_a
    assert_predicate retirado, :citable?
  end

  # ── Los bytes ─────────────────────────────────────────────────────────────

  # LA RAZÓN DE QUE EL ALMACÉN SEA OTRO. `Artifacts::Verify#orphans` enumera el
  # de artefactos y llama huérfano a todo lo que no reclame un `Artifact`: un
  # documento ahí dentro dejaría `matrix:verify_artifacts` en rojo para siempre.
  test "sus bytes van a su propio almacén, y la reconciliación no los ve" do
    document = build_project_document(slug: "acta-precios")

    assert_equal "documents", document.file.blob.service_name
    assert_not_includes Artifacts::Store.keys, document.file.blob.key,
                        "la reconciliación de artefactos lo contaría como huérfano"
  end

  # Y no basta con separar el servicio: en disco `Store#disk_keys` recorre la
  # raíz con `glob("**/*")`, así que anidar una dentro de otra habría anulado la
  # separación sin que nada avisara.
  test "y su raíz en disco no está dentro de la de artefactos" do
    documentos = Pathname(ActiveStorage::Blob.services.fetch(:documents).root)
    artefactos = Pathname(ActiveStorage::Blob.service.root)

    assert_not documentos.to_s.start_with?("#{artefactos}/"),
               "anidadas, `disk_keys` volvería a contar los documentos"
  end
end
