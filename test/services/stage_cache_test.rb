require "test_helper"

# El caché solo es defendible si se puede recomputar.
class StageCacheTest < ActiveSupport::TestCase
  test "reconstruir da lo mismo que dejaron las transiciones" do
    initiative = build_initiative
    3.times { Pipeline::Advance.call(initiative: initiative) }

    assert_empty StageCache.rebuild(Initiative.where(id: initiative.id))
  end

  test "y también después de un retorno" do
    initiative = place(build_initiative, :morfeo)
    Pipeline::SendBack.call(initiative: initiative, to: :neo)

    assert_empty StageCache.rebuild(Initiative.where(id: initiative.id))
  end

  test "un caché mentiroso se corrige desde las filas" do
    initiative = build_initiative
    2.times { Pipeline::Advance.call(initiative: initiative) }
    initiative.update_columns(current_stage: Initiative.current_stages[:gate_2])

    changes = StageCache.rebuild(Initiative.where(id: initiative.id))

    assert_equal 1, changes.size
    assert_predicate initiative.reload, :at_neo?
  end

  test "un evolutivo detenido sigue detenido después de reconstruir" do
    initiative = place(build_initiative, :seraph_verification)
    Pipeline::Escalate.call(initiative: initiative,
                            reason: "inconclusive_environment")

    StageCache.rebuild(Initiative.where(id: initiative.id))

    assert_predicate initiative.reload, :status_escalated?
    assert_predicate initiative, :at_seraph_verification?
  end
end
