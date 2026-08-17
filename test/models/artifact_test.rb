require "test_helper"

# INVARIANTE 3 · lo que matrix escribe es inmutable. Hay tres formas de
# romperlo y las tres tienen su test.
class ArtifactTest < ActiveSupport::TestCase
  test "una columna de un artefacto no se edita" do
    artifact = build_artifact

    error = assert_raises(ActiveRecord::ReadOnlyRecord) do
      artifact.update!(checksum: "sha256:otro")
    end
    assert_match "versión siguiente", error.message
  end

  test "un artefacto no se borra" do
    artifact = build_artifact

    assert_raises(ActiveRecord::ReadOnlyRecord) { artifact.destroy }
    assert Artifact.exists?(artifact.id)
  end

  test "los bytes se adjuntan una vez" do
    artifact = build_artifact
    artifact.body.attach(io: StringIO.new("# dod-031\n"), filename: "v1.md",
                         content_type: "text/markdown")

    assert_predicate artifact.body, :attached?
    assert_equal "# dod-031\n", artifact.body_markdown
  end

  test "y no se reemplazan: es la forma de romper la inmutabilidad que no deja rastro en la tabla" do
    artifact = build_artifact
    artifact.body.attach(io: StringIO.new("original"), filename: "v1.md",
                         content_type: "text/markdown")

    error = assert_raises(ActiveRecord::ReadOnlyRecord) do
      artifact.body.attach(io: StringIO.new("suplantado"), filename: "v1.md",
                           content_type: "text/markdown")
    end
    assert_match "no se reemplazan", error.message
    assert_equal "original", artifact.reload.body_markdown
  end

  test "corregir es publicar la versión siguiente" do
    v1 = build_artifact(version: 1)
    v2 = build_artifact(initiative: v1.initiative, version: 2)

    assert_not_equal v1.storage_key, v2.storage_key
    assert_equal [ 2, 1 ], v1.initiative.artifacts.latest_first.map(&:version)
  end

  test "la clave sigue el esquema congelado en F0" do
    artifact = Artifact.new(storage_key: "artifacts://vivla/dod-031/v2.md")
    artifact.validate

    assert_includes artifact.errors.attribute_names, :storage_key
  end

  # ── F5 · el documento y el cuerpo son dos cosas ───────────────────────────

  test "el documento lleva la cabecera y el cuerpo no" do
    artifact = publish_artifact(body: "# Un DoD\n\n## c0 · algo\n")

    assert artifact.document.start_with?("---\n")
    assert_equal "# Un DoD\n\n## c0 · algo\n", artifact.body_markdown
    assert_equal artifact.storage_key, artifact.stored_front_matter[:key]
  end

  # `FrontMatter.parse` reconoce CUALQUIER bloque `---…---` inicial, no solo el
  # suyo. Sin el guard, un cuerpo que empiece por una regla horizontal perdería
  # su primera sección en silencio.
  test "un cuerpo que empieza por una regla horizontal no pierde texto" do
    body = "---\nkind: no soy un front-matter\n---\n\n# El cuerpo de verdad\n"
    artifact = publish_artifact(body: body)

    assert_equal body, artifact.body_markdown
    assert_includes artifact.body_markdown, "# El cuerpo de verdad"
  end

  # Un artefacto anterior a F5 no lleva cabecera. Sigue leyéndose entero: no
  # hace falta migrar nada, los bytes viejos y los nuevos conviven.
  test "un artefacto sin cabecera devuelve su cuerpo entero" do
    artifact = build_artifact
    artifact.body.attach(io: StringIO.new("# Sin cabecera\n"), filename: "v1.md",
                         content_type: "text/markdown")

    assert_equal "# Sin cabecera\n", artifact.body_markdown
    assert_empty artifact.stored_front_matter
  end

  test "y una cabecera que no es la suya tampoco se reclama" do
    ajeno = publish_artifact(body: "# Del otro\n")
    artifact = build_artifact(initiative: ajeno.initiative, version: 9)
    artifact.body.attach(io: StringIO.new(ajeno.document), filename: "v9.md",
                         content_type: "text/markdown")

    assert_equal ajeno.document, artifact.body_markdown,
                 "si la cabecera dice ser de otro artefacto, se enseña entera"
  end

  test "sin bytes no hay ni documento ni cuerpo" do
    artifact = build_artifact

    assert_nil artifact.document
    assert_nil artifact.body_markdown
    assert_empty artifact.stored_front_matter
  end
end
