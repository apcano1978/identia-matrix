# frozen_string_literal: true

require "test_helper"

class Citations::ResolveConflictTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @initiative = build_initiative(client: @client, code: "ev-031")
    @meeting = build_meeting(client: @client, held_on: Date.new(2026, 5, 2))
    @origin_artifact = build_artifact(initiative: @initiative, kind: :dossier)
    @derived_artifact = build_artifact(initiative: @initiative, kind: :pkg)

    @conflict = CitationConflict.create!(
      detected_at: 6.hours.ago,
      origin_citation: cite(@origin_artifact, "[src:meet/2026-05-02@22:40]"),
      derived_citation: cite(@derived_artifact, "[src:dod/dod-031#c3]"))
  end

  test "registra que gana el origen" do
    Citations::ResolveConflict.call(conflict: @conflict)

    assert_predicate @conflict.reload, :resolved?
    assert_equal CitationConflict::ORIGIN_WINS, @conflict.resolution
  end

  test "marca el artefacto que hizo la afirmación derivada" do
    Citations::ResolveConflict.call(conflict: @conflict)

    assert_equal @derived_artifact, @conflict.reload.flagged_artifact
  end

  # El marcado se DERIVA de `flagged_artifact_id`, no se escribe encima del
  # artefacto: su fila no se toca ni para metadatos.
  test "sin tocar la fila del artefacto" do
    before = @derived_artifact.updated_at

    Citations::ResolveConflict.call(conflict: @conflict)

    assert_equal before, @derived_artifact.reload.updated_at
    assert_not_includes Artifact.column_names, "flagged_for_review"
  end

  test "lo cuenta en el stream de actividad" do
    assert_difference -> { Event.count }, 1 do
      Citations::ResolveConflict.call(conflict: @conflict)
    end

    event = Event.order(:id).last

    assert_equal "CONFLICTO", event.actor
    assert_equal @initiative, event.initiative
    assert_includes event.message, "gana el ORIGEN"
    assert_includes event.message, @derived_artifact.code
  end

  test "nombra a quien lo resolvió cuando se sabe" do
    user = build_platform_user(email_address: "antonio@identiaconsulting.com")

    Citations::ResolveConflict.call(conflict: @conflict, by: user)

    assert_includes Event.order(:id).last.message,
                    "antonio@identiaconsulting.com"
  end

  test "resolver dos veces no duplica nada" do
    Citations::ResolveConflict.call(conflict: @conflict)

    assert_no_difference -> { Event.count } do
      Citations::ResolveConflict.call(conflict: @conflict)
    end
  end

  # ── INVARIANTE 8, por su lado estructural ─────────────────────────────────

  # No basta con que no haya un botón para lo contrario: no puede haber un
  # MÉTODO. Que la única salida sea a favor del origen tiene que poder leerse
  # en la superficie del servicio, sin entrar en su cuerpo.
  test "el servicio expone un solo método, y no hay forma de resolverlo al revés" do
    assert_equal [ :call ], Citations::ResolveConflict.singleton_methods(false)

    surface = (Citations::ResolveConflict.singleton_methods +
               CitationConflict.instance_methods(false)).map(&:to_s)

    assert_empty surface.grep(/derived.*wins|resolve_for_derived|favor/),
                 "hay una vía para dar la razón al derivado"
  end

  test "un conflicto con los niveles cambiados no es válido" do
    invalid = CitationConflict.new(
      detected_at: Time.current,
      origin_citation: cite(@origin_artifact, "[src:spec/spec-031#§2]"),
      derived_citation: cite(@derived_artifact, "[src:doc/acta-precios#p1]"))

    assert_not invalid.valid?
    assert_includes invalid.errors[:derived_citation], "no es una cita derivada"
    assert_includes invalid.errors[:origin_citation], "no es una cita de origen"
  end

  private
    def cite(artifact, raw)
      Citations::Attach.one(citable: artifact, raw: raw, client: @client.id)
    end
end
