require "test_helper"

class Pipeline::CompleteTest < ActiveSupport::TestCase
  setup do
    @client = build_client(slug: "vivla")
    @initiative = place(build_initiative(client: @client, code: "ev-009"),
                        :publication)
  end

  test "cerrar la última etapa es lo único que deja un evolutivo publicado" do
    Pipeline::Complete.call(initiative: @initiative)

    assert_predicate @initiative.reload, :at_publication?
    assert_predicate @initiative, :status_done?
    assert_predicate @initiative.stage_entries.find_by(stage: :publication), :done?
  end

  test "y no se puede cerrar desde otra etapa" do
    otro = place(build_initiative(client: @client), :trinity)

    assert_raises(Pipeline::InvalidTransition) do
      Pipeline::Complete.call(initiative: otro)
    end
  end

  # ── F5 §5 · la etapa 12 deja constancia de dónde quedó publicado ──────────

  # Hasta F5 era un nodo que no hacía nada. Es lo que la maqueta enseña en el
  # nodo 12 de ev-009 y ev-002.
  test "la etapa 12 deja constancia de la clave publicada" do
    Pipeline::Complete.call(initiative: @initiative)

    entry = @initiative.stage_entries.find_by(stage: :publication)

    assert_equal "artifacts://vivla/ev-009", entry.summary
  end

  test "y el evento lo cuenta con la misma clave" do
    Pipeline::Complete.call(initiative: @initiative)

    assert_equal "PUBLICATION · artefactos en artifacts://vivla/ev-009",
                 Event.order(:id).last.message
  end

  # La clave sale de `Artifacts::Key.prefix_for`, no de una cadena compuesta a
  # mano: el esquema está congelado desde F0 y hay un solo sitio que lo sabe.
  test "la clave la compone Artifacts::Key, no la etapa" do
    Pipeline::Complete.call(initiative: @initiative)

    assert_equal Artifacts::Key.prefix_for(client: "vivla", initiative: "ev-009"),
                 @initiative.stage_entries.find_by(stage: :publication).summary
  end

  test "un resumen explícito manda sobre el defecto" do
    Pipeline::Complete.call(initiative: @initiative, summary: "8 artefactos")

    assert_equal "8 artefactos",
                 @initiative.stage_entries.find_by(stage: :publication).summary
  end
end
