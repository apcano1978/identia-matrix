require "test_helper"

# El reinicio: el contador se resetea, el historial no.
class Pipeline::RestartTest < ActiveSupport::TestCase
  test "un reinicio por ciclos agotados vuelve a neo" do
    initiative, escalation = halted("qa_cycles_exhausted",
                                    at: :seraph_verification)
    initiative.update!(qa_cycles_consumed: Initiative::MAX_QA_CYCLES)

    restart(initiative, escalation)

    assert_predicate initiative.reload, :at_neo?
  end

  test "el contador vuelve a cero y la iteración sube" do
    initiative, escalation = halted("qa_cycles_exhausted",
                                    at: :seraph_verification)
    initiative.update!(qa_cycles_consumed: Initiative::MAX_QA_CYCLES,
                       iteration: 3)

    restart(initiative, escalation)

    assert_equal 0, initiative.reload.qa_cycles_consumed
    assert_equal 4, initiative.iteration
  end

  test "pero la escalada se queda en la tabla, resuelta" do
    initiative, escalation = halted("qa_cycles_exhausted",
                                    at: :seraph_verification)

    restart(initiative, escalation)

    assert Escalation.exists?(escalation.id)
    assert_not_predicate escalation.reload, :open?
    assert_not_nil escalation.human_note
    assert_not_nil escalation.resolved_by_user
  end

  test "un reinicio por entorno vuelve a verificar: no hay nada que corregir" do
    initiative, escalation = halted("inconclusive_environment",
                                    at: :seraph_verification)

    restart(initiative, escalation)

    assert_predicate initiative.reload, :at_seraph_verification?
  end

  test "un reinicio por bucle de morfeo lo elige quien reinicia" do
    initiative, escalation = halted("morfeo_returns_exhausted", at: :morfeo)

    restart(initiative, escalation, to: :seraph_dod)

    assert_predicate initiative.reload, :at_seraph_dod?
  end

  test "y si no elige, no se adivina" do
    initiative, escalation = halted("morfeo_returns_exhausted", at: :morfeo)

    error = assert_raises(Pipeline::InvalidTransition) do
      restart(initiative, escalation)
    end
    assert_match "elegir", error.message
  end

  test "un paso irrecorrible no se reinicia: no detuvo el pipeline" do
    initiative = place(build_initiative, :gate_2)
    escalation = Escalation.create!(
      initiative: initiative,
      platform_client_id: initiative.platform_client_id,
      reason: :unwalkable_step, opened_at: Time.current,
      opened_by_user: build_platform_user, guide_step: some_guide_step)

    error = assert_raises(Pipeline::InvalidTransition) do
      restart(initiative, escalation)
    end
    assert_match "autorizando", error.message
  end

  private
    def halted(reason, at:)
      initiative = place(build_initiative, at)
      result = Pipeline::Escalate.call(initiative: initiative, reason: reason)

      [ initiative, result.escalation ]
    end

    def restart(initiative, escalation, to: nil)
      Pipeline::Restart.call(
        initiative: initiative, escalation: escalation, to: to,
        human_note: build_note(initiative),
        resolved_by_user: build_platform_user)
    end

    def some_guide_step
      report = build_report(outcome: :conforme)
      guide = TestGuide.create!(initiative: report.initiative,
                                verification_report: report,
                                code: "guia-pruebas-#{report.initiative.number}")
      GuideStep.create!(test_guide: guide, position: 0, title: "Comprobar",
                        evidence_origin: :sole_evidence)
    end
end
