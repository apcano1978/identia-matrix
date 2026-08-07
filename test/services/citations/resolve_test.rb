# frozen_string_literal: true

require "test_helper"

# Atar una cita a su fuente. Una prueba por rama de la tabla de F4 §1, más las
# dos reglas que gobiernan el servicio: resolver contra la FUENTE y no cruzar
# nunca la frontera de cliente.
class Citations::ResolveTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @initiative = build_initiative(client: @client, code: "ev-031")
  end

  # ── Las seis ramas ─────────────────────────────────────────────────────────

  test "una cita de código resuelve contra el repositorio que la califica" do
    repository = build_repository(client: @client, name: "booking-core")

    assert_equal repository,
                 resolve("[src:code/booking-core:rates.ts#L40@4f2a9c1]")
  end

  test "una cita de verificación resuelve contra el repositorio, no contra un artefacto" do
    repository = build_repository(client: @client, name: "pricing-svc")

    assert_equal repository, resolve("[src:verify/pricing-svc:run-174#L88]")
  end

  test "una cita de documento resuelve por su slug" do
    document = build_document(client: @client, slug: "acta-precios")

    assert_equal document, resolve("[src:doc/acta-precios#p2]")
  end

  test "una cita de reunión resuelve por su fecha" do
    meeting = build_meeting(client: @client, held_on: Date.new(2026, 5, 2))

    assert_equal meeting, resolve("[src:meet/2026-05-02@22:40]")
  end

  test "una cita de nota resuelve contra la nota de ese día y ese autor" do
    note = HumanNote.create!(initiative: @initiative,
                             platform_client: @client,
                             author_user: build_platform_user,
                             code: "2026-05-08-ap",
                             body: "Lo que cambió antes de reanudar.")

    assert_equal note, resolve("[src:note/2026-05-08-ap]")
  end

  test "las cuatro citas derivadas de artefacto resuelven por su código" do
    %i[spec dod pkg close].each do |kind|
      artifact = build_artifact(initiative: @initiative, kind: kind)

      assert_equal artifact, resolve("[src:#{kind}/#{artifact.code}#§2]"),
                   "una cita de tipo #{kind} tiene que resolver contra su artefacto"
    end
  end

  # ── El desempate de la enmienda ────────────────────────────────────────────

  test "con dos reuniones el mismo día, el sufijo decide cuál" do
    primera = build_meeting(client: @client, slug: "unificacion-precio",
                            held_on: Date.new(2026, 5, 2))
    segunda = build_meeting(client: @client, slug: "comite-de-direccion",
                            held_on: Date.new(2026, 5, 2))

    assert_equal primera, resolve("[src:meet/2026-05-02-unificacion-precio]")
    assert_equal segunda, resolve("[src:meet/2026-05-02-comite-de-direccion]")
  end

  test "un sufijo que no existe ese día no resuelve a la otra reunión" do
    build_meeting(client: @client, slug: "unificacion-precio",
                  held_on: Date.new(2026, 5, 2))

    assert_nil resolve("[src:meet/2026-05-02-comite-de-direccion]")
  end

  # ── INVARIANTE 10 · la frontera de cliente ─────────────────────────────────

  test "un repositorio de otro cliente no resuelve" do
    otro = build_client(slug: "caser")
    build_repository(client: otro, name: "booking-core")

    assert_nil resolve("[src:code/booking-core:rates.ts#L40@4f2a9c1]")
  end

  test "un documento de otro cliente no resuelve" do
    build_document(client: build_client(slug: "caser"), slug: "acta-precios")

    assert_nil resolve("[src:doc/acta-precios#p2]")
  end

  test "un artefacto de otro cliente no resuelve" do
    ajena = build_initiative(client: build_client(slug: "caser"))
    artifact = build_artifact(initiative: ajena, kind: :spec)

    assert_nil resolve("[src:spec/#{artifact.code}#§2]")
  end

  # ── Lo que no rompe ────────────────────────────────────────────────────────

  test "una cita sin fuente contra la que resolver devuelve nulo, no levanta" do
    assert_nil resolve("[src:doc/no-existe#p1]")
    assert_nil resolve("[src:code/no-existe:a.ts#L1@abcdef1]")
  end

  test "resolver sin cliente devuelve nulo: la frontera no es opcional" do
    build_document(client: @client, slug: "acta-precios")
    reference = Citations::Parse.call!("[src:doc/acta-precios#p2]")

    assert_nil Citations::Resolve.call(reference, client: nil)
  end

  test "acepta el cliente como objeto o como id, y da lo mismo" do
    document = build_document(client: @client, slug: "acta-precios")
    reference = Citations::Parse.call!("[src:doc/acta-precios#p2]")

    assert_equal document, Citations::Resolve.call(reference, client: @client)
    assert_equal document, Citations::Resolve.call(reference, client: @client.id)
  end

  test "una cita derivada resuelve contra la ÚLTIMA versión del artefacto" do
    build_artifact(initiative: @initiative, kind: :spec, version: 1)
    cuarta = build_artifact(initiative: @initiative, kind: :spec, version: 4)

    assert_equal cuarta, resolve("[src:spec/#{cuarta.code}#§2]")
  end

  # ── El calificador de repositorio es una pregunta aparte ───────────────────

  test "repository_for solo responde para los tipos que exigen calificador" do
    repository = build_repository(client: @client, name: "booking-core")

    assert_equal repository,
                 repository_for("[src:code/booking-core:rates.ts#L40@4f2a9c1]")
    assert_equal repository, repository_for("[src:verify/booking-core:run-1#L8]")
    assert_nil repository_for("[src:doc/acta-precios#p2]")
  end

  # ── §7.7 · el slug congelado sobrevive a un renombrado en platform ─────────

  test "un documento renombrado en platform sigue resolviendo por su slug" do
    original = build_document(client: @client, slug: "acta-precios",
                              title: "Acta · unificación del precio de festivos")
    citation = "[src:doc/acta-precios#p2]"
    assert resolve(citation), "tiene que resolver antes del renombrado"

    # Platform renombra el documento: nuevo título y nuevo slug.
    Platform::Record.writing do
      Platform::Projection.upsert(
        Platform::Document,
        [ { platform_id: original.platform_id,
            slug: "acta-precios-renombrada",
            title: "Acta · precios (renombrada en platform)",
            client_platform_id: @client.platform_id } ],
        "test")
    end
    document = Platform::Document.find_by!(slug: "acta-precios")

    assert_equal "Acta · precios (renombrada en platform)", document.title,
                 "el título SÍ se refresca"
    assert_equal document, resolve(citation),
                 "el slug está congelado: la cita ya emitida sigue resolviendo"
  end

  private
    def resolve(raw)
      Citations::Resolve.call(Citations::Parse.call!(raw), client: @client)
    end

    def repository_for(raw)
      Citations::Resolve.repository_for(Citations::Parse.call!(raw),
                                        client: @client)
    end
end
