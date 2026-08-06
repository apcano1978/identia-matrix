require "test_helper"

# Las cinco bifurcaciones hacia atrás de F2 §2.2. Cada una dice a dónde va, qué
# contador sube y cuál NO — que es la mitad del valor de la tabla.
class Pipeline::SendBackTest < ActiveSupport::TestCase
  # 1 · MORFEO encuentra un bloqueante en la spec → NEO.
  test "morfeo devuelve a neo sin consumir ciclo de QA" do
    initiative = place(build_initiative, :morfeo)

    result = Pipeline::SendBack.call(initiative: initiative, to: :neo,
                                     actor: "MORFEO")

    assert_predicate result, :sent_back?
    assert_predicate initiative.reload, :at_neo?
    assert_equal 2, initiative.iteration
    assert_equal 0, initiative.qa_cycles_consumed
  end

  # 2 · MORFEO encuentra un bloqueante en el DoD → SERAPH, no NEO.
  test "morfeo devuelve al DoD cuando el bloqueante es del contrato" do
    initiative = place(build_initiative, :morfeo)

    Pipeline::SendBack.call(initiative: initiative, to: :seraph_dod,
                            actor: "MORFEO")

    assert_predicate initiative.reload, :at_seraph_dod?
    assert_equal 2, initiative.iteration
    assert_equal 0, initiative.qa_cycles_consumed
  end

  # 3 · El informe trae un ✕ → NEO, y este SÍ consume.
  test "un ✕ devuelve a neo y sube los dos contadores" do
    initiative, report = verified(:unmet)

    Pipeline::SendBack.call(initiative: initiative, to: :neo, actor: "SERAPH",
                            verification_report: report)

    assert_predicate initiative.reload, :at_neo?
    assert_equal 2, initiative.iteration
    assert_equal 1, initiative.qa_cycles_consumed
  end

  test "un informe de solo ? devuelve sin consumir ciclo" do
    initiative, report = verified(:inconclusive)

    Pipeline::SendBack.call(initiative: initiative, to: :neo,
                            verification_report: report)

    assert_equal 2, initiative.reload.iteration
    assert_equal 0, initiative.qa_cycles_consumed
  end

  # 4 · GATE 2 rechaza → NEO, sube iteration pero NO el de QA.
  test "un rechazo en GATE 2 no es un ✕ de SERAPH" do
    initiative = place(build_initiative, :gate_2)

    Pipeline::SendBack.call(initiative: initiative, to: :neo, actor: "Antonio")

    assert_predicate initiative.reload, :at_neo?
    assert_equal 2, initiative.iteration
    assert_equal 0, initiative.qa_cycles_consumed
  end

  # 5 · GATE 1 devuelve a TRINITY, y exige nota.
  test "gate 1 devuelve a trinity, no a neo: lo que está mal es el paquete" do
    initiative = place(build_initiative, :gate_1)

    Pipeline::SendBack.call(initiative: initiative, to: :trinity,
                            human_note: build_note(initiative))

    assert_predicate initiative.reload, :at_trinity?
    assert_equal 2, initiative.iteration
  end

  test "y sin nota no devuelve: trinity volvería a sellar lo mismo" do
    initiative = place(build_initiative, :gate_1)

    error = assert_raises(Pipeline::InvalidTransition) do
      Pipeline::SendBack.call(initiative: initiative, to: :trinity)
    end
    assert_match "nota humana", error.message
  end

  # 6 · El tope. El tercer ✕ no gasta un ciclo que no existe: para.
  test "con los ciclos agotados escala en vez de subir a tres" do
    initiative, report = verified(:unmet)
    initiative.update!(qa_cycles_consumed: Initiative::MAX_QA_CYCLES)

    result = Pipeline::SendBack.call(initiative: initiative, to: :neo,
                                     verification_report: report)

    assert_predicate result, :escalated?
    assert_equal "qa_cycles_exhausted", result.escalation.reason
    assert_equal Initiative::MAX_QA_CYCLES, initiative.reload.qa_cycles_consumed
    assert_predicate initiative, :at_seraph_verification?
    assert_predicate initiative, :status_escalated?
  end

  test "la tercera devolución de morfeo escala en vez de reintentar" do
    initiative = place(build_initiative, :morfeo)

    Pipeline::MAX_MORFEO_RETURNS.times do
      Pipeline::SendBack.call(initiative: initiative, to: :neo)
      place(initiative, :morfeo)
    end

    result = Pipeline::SendBack.call(initiative: initiative, to: :neo)

    assert_predicate result, :escalated?
    assert_equal "morfeo_returns_exhausted", result.escalation.reason
  end

  test "el contador de morfeo se deriva de las filas: no hay columna" do
    assert_not_includes Initiative.column_names, "morfeo_returns"
  end

  test "un retorno inserta con la iteración nueva en vez de sobrescribir" do
    initiative = place(build_initiative, :morfeo)

    Pipeline::SendBack.call(initiative: initiative, to: :neo)
    place(initiative, :morfeo)
    Pipeline::SendBack.call(initiative: initiative, to: :neo)

    # Dos filas de NEO, una por vuelta. Sin `iteration` la segunda chocaría
    # contra el índice único y el historial se perdería.
    assert_equal [ 2, 3 ], initiative.stage_entries.where(stage: :neo)
                                     .order(:iteration).pluck(:iteration)
  end

  test "hacia adelante no se devuelve" do
    initiative = place(build_initiative, :neo)

    assert_raises(Pipeline::InvalidTransition) do
      Pipeline::SendBack.call(initiative: initiative, to: :gate_2)
    end
  end

  private
    def verified(result)
      dod = build_dod
      report = build_report(dod: dod)
      Verdict.create!(verification_report: report,
                      dod_criterion: build_criterion(dod: dod),
                      result: result)

      [ place(dod.initiative, :seraph_verification), report.reload ]
    end
end
