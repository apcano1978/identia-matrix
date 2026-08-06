require "test_helper"

# No son invariantes, pero protegen tres decisiones que costaron discusión y que
# nada más en el código recuerda.
class DecisionsTest < ActiveSupport::TestCase
  # 1 · Agotados los dos ciclos, el siguiente ✕ no gasta un ciclo que no existe.
  test "el tercer ✕ crea una escalada y detiene, en vez de subir a tres" do
    initiative, report = verified(:unmet)
    initiative.update!(qa_cycles_consumed: Initiative::MAX_QA_CYCLES)

    result = Pipeline::SendBack.call(initiative: initiative, to: :neo,
                                     verification_report: report)

    assert_predicate result, :escalated?
    assert_equal "qa_cycles_exhausted", result.escalation.reason
    assert_equal 2, initiative.reload.qa_cycles_consumed
    assert_predicate initiative, :status_escalated?
  end

  # 2 · El contador se resetea; el historial no.
  test "el reinicio pone el contador a cero y la escalada sigue en la tabla" do
    initiative, report = verified(:unmet)
    initiative.update!(qa_cycles_consumed: Initiative::MAX_QA_CYCLES)
    escalation = Pipeline::SendBack.call(initiative: initiative, to: :neo,
                                         verification_report: report).escalation

    Pipeline::Restart.call(initiative: initiative, escalation: escalation,
                           human_note: build_note(initiative),
                           resolved_by_user: build_platform_user)

    assert_equal 0, initiative.reload.qa_cycles_consumed
    assert_predicate initiative, :at_neo?
    assert Escalation.exists?(escalation.id)
    assert_not_predicate escalation.reload, :open?
  end

  # 3 · El caché solo es defendible si se puede recomputar.
  test "rebuild_stage_cache da el mismo valor que dejaron las transiciones" do
    DesignSeed.call

    assert_empty StageCache.rebuild
  end

  test "y corrige un caché que mienta" do
    initiative = build_initiative
    2.times { Pipeline::Advance.call(initiative: initiative) }
    initiative.update_columns(current_stage: Initiative.current_stages[:link])

    changes = StageCache.rebuild(Initiative.where(id: initiative.id))

    assert_equal 1, changes.size
    assert_predicate initiative.reload, :at_neo?
  end

  private
    def verified(*results)
      dod = build_dod
      report = build_report(dod: dod)
      results.each_with_index do |result, index|
        Verdict.create!(verification_report: report, result: result,
                        dod_criterion: build_criterion(dod: dod, key: "c#{index}"))
      end

      [ place(dod.initiative, :seraph_verification), report.reload ]
    end
end
