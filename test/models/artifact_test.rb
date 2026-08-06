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
end
