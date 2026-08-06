require "test_helper"

# INVARIANTE 3 · Matrix solo escribe en su bucket, y lo que escribe es inmutable.
#
# Hay TRES formas de romperlo y las tres tienen que estar cerradas: editar una
# columna, borrar la fila y volver a adjuntar otros bytes.
class WhatMatrixWritesIsImmutableTest < ActiveSupport::TestCase
  test "un artefacto no se edita, no se borra y no se reemplaza" do
    artifact = build_artifact
    artifact.body.attach(io: StringIO.new("original"), filename: "v1.md",
                         content_type: "text/markdown")

    # Cada intento parte de una copia limpia: son tres formas independientes de
    # romperlo, no una secuencia.
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      artifact.reload.update!(checksum: "sha256:otro")
    end
    assert_raises(ActiveRecord::ReadOnlyRecord) { artifact.reload.destroy }
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      artifact.reload.body.attach(io: StringIO.new("otro"), filename: "v1.md",
                                  content_type: "text/markdown")
    end

    assert Artifact.exists?(artifact.id)
    assert_equal "original", artifact.reload.body_markdown
  end

  test "dos artefactos no comparten clave" do
    first = build_artifact
    duplicate = Artifact.new(first.attributes.except("id", "created_at",
                                                     "updated_at"))

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :storage_key
  end

  test "la clave sigue el esquema congelado en F0 y lleva cliente, evolutivo, código y versión" do
    artifact = build_artifact
    parsed = Artifacts::Key.parse(artifact.storage_key)

    assert_equal artifact.platform_client.slug, parsed.client
    assert_equal artifact.initiative.code, parsed.initiative
    assert_equal artifact.code, parsed.code
    assert_equal artifact.version, parsed.version
  end

  test "corregir es publicar la versión siguiente" do
    v1 = build_artifact(version: 1)
    v2 = build_artifact(initiative: v1.initiative, version: 2)

    assert_not_equal v1.storage_key, v2.storage_key
    assert_equal 2, v1.initiative.artifacts.count
  end
end
