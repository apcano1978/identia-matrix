# frozen_string_literal: true

require "test_helper"

# LA PREMISA DE LA RECONCILIACIÓN, hecha comprobable.
#
# `Artifacts::Verify#orphans` enumera el almacén y llama huérfano a **todo objeto
# que no reclame un `Artifact`**. Su comentario dice por qué puede permitírselo:
# *«el bucket es PROPIO de matrix: aquí no se guarda otra cosa, así que lo que no
# case es huérfano por definición»*.
#
# Eso era verdad **por suerte**. `CiCheck#log` está declarado desde F10 y
# comparte servicio con `Artifact#body`; nadie lo ha adjuntado todavía. El día
# que alguien lo haga —o que aparezca un tercer adjunto— `matrix:verify_artifacts`
# se pondría en rojo con un huérfano por fichero, y el mensaje no diría por qué.
#
# F12 es lo primero que habría roto la premisa: un documento subido es un adjunto
# más. Por eso vive en su propio almacén (`config/storage.yml`), y por eso existe
# este test — para que la próxima vez el rojo aparezca AQUÍ, con la explicación
# al lado, y no en el latido.
class ElAlmacenDeArtefactosEsSoloDeArtefactosTest < ActiveSupport::TestCase
  test "todo blob del almacén que enumera la reconciliación es de un artefacto" do
    publish_artifact
    build_project_document

    ajenos = ActiveStorage::Attachment
             .joins(:blob)
             .where(active_storage_blobs: { service_name: reconciled_service })
             .where.not(record_type: "Artifact")
             .map { |a| "#{a.record_type}##{a.name}" }
             .uniq

    assert_empty ajenos,
                 "hay adjuntos ajenos donde la reconciliación solo espera " \
                 "artefactos: o van a su propio servicio, o `Verify#orphans` " \
                 "tiene que dejar de dar por hecho que todo lo que hay es suyo"
  end

  # Y el documento, en el suyo. Es la otra mitad de la misma afirmación: no basta
  # con que no esté aquí, tiene que estar en alguna parte.
  test "y el documento subido está en el suyo, que es otro" do
    document = build_project_document

    assert_equal "documents", document.file.blob.service_name
    assert_not_equal reconciled_service, document.file.blob.service_name
  end

  private
    # El servicio que `Artifacts::Store.keys` recorre por defecto, que es el
    # mismo del que cuelga `Artifact#body`.
    def reconciled_service = ActiveStorage::Blob.service.name.to_s
end
