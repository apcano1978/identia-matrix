# frozen_string_literal: true

require "test_helper"

# La reconciliación entre el registro y el bucket. Las tres divergencias son
# problemas DISTINTOS y por eso se comprueban por separado.
class Artifacts::VerifyTest < ActiveSupport::TestCase
  # El servicio `test` apunta a tmp/storage, que comparte toda la suite: los
  # blobs que dejen otros tests aparecerían aquí como huérfanos, y «objeto sin
  # fila» es justo una de las cosas que hay que medir. Hace falta un almacén
  # desechable por test.
  #
  # Se le cambia la RAÍZ al servicio existente en vez de sustituirlo por otro:
  # un blob no resuelve su servicio con `Blob.service`, sino buscando su
  # `service_name` en el registro. Un servicio nuevo se usaría para subir y no
  # para descargar, que es peor que no aislar nada.
  setup do
    @service = ActiveStorage::Blob.service
    @previous_root = @service.root
    @root = Dir.mktmpdir("matrix-verify")
    @service.instance_variable_set(:@root, @root)

    @client = build_client(slug: "vivla")
    @initiative = build_initiative(client: @client, code: "ev-031")
  end

  teardown do
    @service.instance_variable_set(:@root, @previous_root)
    FileUtils.remove_entry(@root, true)
  end

  test "un registro sano no tiene divergencias" do
    publish_artifact(initiative: @initiative, kind: :spec)
    publish_artifact(initiative: @initiative, kind: :dod)

    report = Artifacts::Verify.call

    assert_equal 2, report.checked
    assert_not_predicate report, :divergences?
    assert_empty report.divergences
  end

  test "un registro vacío tampoco" do
    report = Artifacts::Verify.call

    assert_equal 0, report.checked
    assert_not_predicate report, :divergences?
  end

  # ── Las tres divergencias, una a una ──────────────────────────────────────

  test "fila sin objeto: se registró algo que no llegó al bucket" do
    artifact = publish_artifact(initiative: @initiative, kind: :spec)
    ActiveStorage::Blob.service.delete(artifact.body.blob.key)

    report = Artifacts::Verify.call

    assert_equal 1, report.missing_objects.size
    assert_equal artifact.storage_key, report.missing_objects.sole.key
    assert_empty report.checksum_mismatches
  end

  test "y una fila que nunca tuvo bytes cuenta igual" do
    artifact = build_artifact(initiative: @initiative)

    report = Artifacts::Verify.call

    assert_equal [ artifact.storage_key ], report.missing_objects.map(&:key)
    assert_includes report.missing_objects.sole.detail, "no tiene bytes"
  end

  # Es literalmente lo que deja una publicación fallida: los bytes suben y la
  # fila no llega a existir. Purgable, sin consecuencias.
  test "objeto sin fila: un blob huérfano" do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("# nadie me reclama\n"), filename: "v1.md",
      content_type: "text/markdown")

    report = Artifacts::Verify.call

    assert_equal 1, report.orphan_objects.size
    assert_empty report.missing_objects
    assert_empty report.checksum_mismatches
  end

  # El hallazgo grave, y el que justifica que esto exista. Se escribe POR DETRÁS
  # de Rails: `refuse_body_replacement` no se entera porque nunca se toca el
  # modelo — que es exactamente el ataque que este chequeo detecta.
  test "checksum distinto: alguien tocó el contenido sin pasar por el modelo" do
    artifact = publish_artifact(initiative: @initiative, kind: :spec,
                                body: "# El original\n")
    suplantado = artifact.document.sub("El original", "Lo que puso otro")

    ActiveStorage::Blob.service.upload(
      artifact.body.blob.key, StringIO.new(suplantado),
      checksum: Digest::MD5.base64digest(suplantado))

    report = Artifacts::Verify.call

    assert_equal 1, report.checksum_mismatches.size
    assert_equal artifact.storage_key, report.checksum_mismatches.sole.key
    assert_empty report.missing_objects
  end

  test "y el detalle enseña los tres checksums para poder compararlos" do
    artifact = publish_artifact(initiative: @initiative, kind: :spec,
                                body: "# El original\n")
    suplantado = artifact.document.sub("El original", "Otro")
    ActiveStorage::Blob.service.upload(
      artifact.body.blob.key, StringIO.new(suplantado),
      checksum: Digest::MD5.base64digest(suplantado))

    detail = Artifacts::Verify.call.checksum_mismatches.sole.detail

    assert_includes detail, "registrado"
    assert_includes detail, "cabecera"
    assert_includes detail, "real"
  end

  # Alterar solo la cabecera y dejar el cuerpo intacto también es tocar el
  # contenido: el front-matter es parte del artefacto.
  test "tocar solo la cabecera también se detecta" do
    artifact = publish_artifact(initiative: @initiative, kind: :spec)
    suplantado = artifact.document.sub(/^checksum: .*/, "checksum: sha256:mentira")
    ActiveStorage::Blob.service.upload(
      artifact.body.blob.key, StringIO.new(suplantado),
      checksum: Digest::MD5.base64digest(suplantado))

    assert_equal 1, Artifacts::Verify.call.checksum_mismatches.size
  end

  # Las tres a la vez, para comprobar que no se pisan ni se suman en un
  # contador único: son problemas distintos y se atienden distinto.
  test "las tres divergencias se cuentan por separado" do
    publish_artifact(initiative: @initiative, kind: :dossier)

    sin_objeto = publish_artifact(initiative: @initiative, kind: :spec)
    ActiveStorage::Blob.service.delete(sin_objeto.body.blob.key)

    tocado = publish_artifact(initiative: @initiative, kind: :dod,
                              body: "# El original\n")
    tamper(tocado)

    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("huérfano"), filename: "v1.md",
      content_type: "text/markdown")

    report = Artifacts::Verify.call

    assert_equal 3, report.checked
    assert_equal [ sin_objeto.storage_key ], report.missing_objects.map(&:key)
    assert_equal 1, report.orphan_objects.size
    assert_equal [ tocado.storage_key ], report.checksum_mismatches.map(&:key)
    assert_equal 3, report.divergences.size
  end

  private
    # Escribe por detrás de Rails, que es como se rompe la inmutabilidad sin
    # dejar rastro en la tabla.
    def tamper(artifact, replacement = "Lo que puso otro")
      suplantado = artifact.document.sub("El original", replacement)

      ActiveStorage::Blob.service.upload(
        artifact.body.blob.key, StringIO.new(suplantado),
        checksum: Digest::MD5.base64digest(suplantado))
    end
end
