require "test_helper"

# INVARIANTE 11 · no se puede estar devuelto a NEO y esperando GATE 2 a la vez.
class TestGuideTest < ActiveSupport::TestCase
  test "hay guía de pruebas sobre un informe conforme" do
    guide = TestGuide.new(initiative: report(:conforme).initiative,
                          verification_report: report(:conforme),
                          code: "guia-pruebas-031")

    assert_predicate guide, :valid?
  end

  test "no la hay sobre un informe devuelto" do
    devuelto = report(:returned)
    guide = TestGuide.new(initiative: devuelto.initiative,
                          verification_report: devuelto, code: "guia-pruebas-014")

    assert_not guide.valid?
    assert_match "devuelto", guide.errors[:verification_report].to_sentence
  end

  test "ni sobre uno escalado" do
    escalado = report(:escalated)
    guide = TestGuide.new(initiative: escalado.initiative,
                          verification_report: escalado, code: "guia-pruebas-014")

    assert_not guide.valid?
  end

  test "un paso eximido no cuenta como recorrido" do
    guide = conforme_guide
    steps = 3.times.map { |i| step(guide, i) }
    steps[0].update!(walked_at: Time.current, walked_by_user: build_platform_user)
    exempt(steps[1])

    assert_equal({ total: 3, walked: 1, exempted: 1, pending: 1 },
                 guide.reload.coverage)
  end

  test "eximir sin quién ni escalada es saltarse el paso" do
    invalid = step(conforme_guide, 0)
    invalid.exempted_at = Time.current

    assert_not invalid.valid?
    assert_includes invalid.errors.attribute_names, :exempted_by_user
    assert_includes invalid.errors.attribute_names, :escalation
  end

  test "un paso crítico sin resolver bloquea GATE 2" do
    guide = conforme_guide
    criterion = build_criterion(dod: guide.verification_report.definition_of_done,
                                critical: true)
    blocking = step(guide, 0, dod_criterion: criterion)

    assert_equal [ blocking ], guide.reload.blocking_steps

    exempt(blocking)

    assert_empty guide.reload.blocking_steps
  end

  private
    def report(outcome)
      @reports ||= {}
      @reports[outcome] ||= build_report(outcome: outcome)
    end

    def conforme_guide
      @conforme_guide ||= begin
        conforme = report(:conforme)
        TestGuide.create!(initiative: conforme.initiative,
                          verification_report: conforme,
                          code: "guia-pruebas-#{conforme.initiative.number}")
      end
    end

    def step(guide, position, **attributes)
      GuideStep.create!(test_guide: guide, position: position,
                        title: "Comprobar algo", evidence_origin: :sole_evidence,
                        **attributes)
    end

    def exempt(guide_step)
      initiative = guide_step.test_guide.initiative
      escalation = Escalation.create!(
        initiative: initiative, platform_client: initiative.platform_client,
        reason: :unwalkable_step, opened_at: Time.current,
        opened_by_user: build_platform_user, guide_step: guide_step)
      guide_step.update!(exempted_at: Time.current,
                         exempted_by_user: build_platform_user,
                         escalation: escalation)
    end
end
