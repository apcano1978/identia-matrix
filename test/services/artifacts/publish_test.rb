# frozen_string_literal: true

require "test_helper"

class Artifacts::PublishTest < ActiveSupport::TestCase
  BODY = <<~MARKDOWN
    # Cierre · ev-031

    ## §1 · Qué se hizo

    El precio de festivos se unificó [src:doc/acta-precios#p2].
  MARKDOWN

  setup do
    @client = build_client(slug: "vivla")
    @initiative = build_initiative(client: @client, code: "ev-031")
    @document = build_document(client: @client, slug: "acta-precios")
    @run = build_run(initiative: @initiative)
  end

  # ── §7.1 · publicar ────────────────────────────────────────────────────────

  test "publicar deja la clave, la versión y el checksum del cuerpo" do
    result = publish

    assert_equal "artifacts://vivla/ev-031/close-031/v1.md", result.key
    assert_equal result.key, result.artifact.storage_key
    assert_equal "close-031", result.artifact.code
    assert_equal 1, result.artifact.version
    assert_equal Artifacts::FrontMatter.checksum_for(BODY), result.checksum
  end

  test "y los bytes llevan el front-matter delante" do
    artifact = publish.artifact

    assert artifact.document.start_with?("---\n"),
           "el documento tiene que empezar por la cabecera"
    assert_equal artifact.storage_key, artifact.stored_front_matter[:key]
    assert_equal artifact.checksum, artifact.stored_front_matter[:checksum]
  end

  # El checksum es del CUERPO, no del fichero: el front-matter contiene el
  # checksum y no puede calcularse sobre sí mismo.
  test "el checksum es del cuerpo, no del documento" do
    artifact = publish.artifact

    assert_equal artifact.checksum,
                 Artifacts::FrontMatter.checksum_for(artifact.body_markdown)
    assert_not_equal artifact.checksum,
                     Artifacts::FrontMatter.checksum_for(artifact.document)
  end

  test "la columna front_matter y la cabecera incrustada dicen lo mismo" do
    artifact = publish.artifact

    assert_equal artifact.front_matter.symbolize_keys,
                 artifact.stored_front_matter
  end

  test "la cadena de procedencia va en derives_from" do
    spec = publish(kind: :spec).artifact
    dod = publish(kind: :dod, derives_from: spec).artifact

    assert_equal spec.storage_key, dod.stored_front_matter[:derives_from]
  end

  test "el dossier arranca la cadena y no deriva de nada" do
    assert_nil publish(kind: :dossier).artifact.stored_front_matter[:derives_from]
  end

  # ── §7.2 · reescribir una clave falla, y con un error explícito ────────────

  test "republicar una clave ya publicada falla, y dice cuál" do
    publish

    error = assert_raises(Artifacts::Publish::AlreadyPublished) { publish(version: 1) }

    assert_includes error.message, "artifacts://vivla/ev-031/close-031/v1.md"
    assert_includes error.message, "publicar la versión siguiente"
  end

  test "sin pedir versión, cada publicación es la siguiente" do
    assert_equal 1, publish(kind: :dod).artifact.version
    assert_equal 2, publish(kind: :dod).artifact.version
    assert_equal 3, publish(kind: :dod).artifact.version
  end

  # ── §7.6 · una subida fallida no deja fila ────────────────────────────────

  # Es lo que justifica el orden de §2: subir antes de registrar. Una clave
  # inmutable reservada para un contenido que no existe es mucho peor que un
  # blob huérfano, que se purga sin consecuencias.
  test "una subida fallida no deja fila" do
    antes = Artifact.count

    ActiveStorage::Blob.service.stub(:upload, ->(*, **) { raise ActiveStorage::IntegrityError }) do
      assert_raises(ActiveStorage::IntegrityError) { publish }
    end

    assert_equal antes, Artifact.count
    assert_nil Artifact.find_by(storage_key: "artifacts://vivla/ev-031/close-031/v1.md")
  end

  test "y la clave sigue libre después del fallo" do
    ActiveStorage::Blob.service.stub(:upload, ->(*, **) { raise ActiveStorage::IntegrityError }) do
      assert_raises(ActiveStorage::IntegrityError) { publish }
    end

    assert_equal "artifacts://vivla/ev-031/close-031/v1.md", publish.key
  end

  # ── Las citas salen del cuerpo ─────────────────────────────────────────────

  test "las citas se atan desde el cuerpo, no desde el documento" do
    artifact = publish.artifact

    assert_equal [ "[src:doc/acta-precios#p2]" ], artifact.citations.pluck(:raw)
    assert_equal @document, artifact.citations.sole.target
  end

  # El front-matter lleva `derives_from: artifacts://…`, que NO es una cita: la
  # gramática exige corchetes. Se afirma de todos modos, porque es justo el tipo
  # de cosa que un cambio futuro de la cabecera convertiría en un problema mudo.
  test "el front-matter no inventa citas" do
    spec = publish(kind: :spec).artifact
    dod = publish(kind: :dod, derives_from: spec).artifact

    referencias, = Citations::Parse.scan(dod.document)

    assert_equal dod.citations.pluck(:raw).sort, referencias.map(&:raw).uniq.sort
  end

  private
    def publish(kind: :close, **options)
      Artifacts::Publish.call(initiative: @initiative, kind: kind, body: BODY,
                              produced_at: Time.zone.parse("2026-05-02 10:00"),
                              produced_by_run: @run, **options)
    end
end
