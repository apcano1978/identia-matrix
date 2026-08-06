require "test_helper"

class Pipeline::AdvanceTest < ActiveSupport::TestCase
  test "avanzar hace las tres cosas en la misma transacción" do
    initiative = place(build_initiative, :tank)

    assert_difference [ "StageEntry.count", "Event.count" ], 1 do
      Pipeline::Advance.call(initiative: initiative, actor: "TANK")
    end

    assert_predicate initiative.reload, :at_neo?
    assert_predicate initiative, :status_active?
    assert_equal "stage_advanced", Event.last.kind
  end

  test "la etapa que se deja queda cerrada, no colgando" do
    initiative = place(build_initiative, :tank)

    Pipeline::Advance.call(initiative: initiative)

    left = initiative.stage_entries.find_by(stage: :tank)
    assert_predicate left, :done?
    assert_not_nil left.exited_at
  end

  test "avanzar no toca ninguno de los dos contadores" do
    initiative = place(build_initiative, :neo)

    Pipeline::Advance.call(initiative: initiative)

    assert_equal 1, initiative.reload.iteration
    assert_equal 0, initiative.qa_cycles_consumed
  end

  test "las doce etapas encadenan cuando las dos paradas están cumplidas" do
    initiative = build_initiative
    satisfy_preconditions(initiative)

    11.times { Pipeline::Advance.call(initiative: initiative) }

    assert_predicate initiative.reload, :at_publication?
    assert_equal 12, initiative.stage_entries.count
  end

  test "y sin ellas no encadenan: se para en la primera" do
    initiative = build_initiative

    error = assert_raises(Pipeline::PreconditionFailed) do
      11.times { Pipeline::Advance.call(initiative: initiative) }
    end

    assert_match "MORFEO", error.message
    assert_predicate initiative.reload, :at_morfeo?
  end

  test "desde la última no se avanza" do
    initiative = place(build_initiative, :publication)

    assert_raises(Pipeline::InvalidTransition) do
      Pipeline::Advance.call(initiative: initiative)
    end
  end

  private
    def satisfy_preconditions(initiative)
      dod = build_dod(initiative: initiative)
      dod.update!(reviewed_by_run: AgentRun.create!(
        initiative: initiative, agent: :morfeo, purpose: :review,
        code: "morfeo/run-#{initiative.number}", status: :ok))

      repository = build_repository(client: initiative.platform_client)
      package = WorkPackage.create!(initiative: initiative,
                                    code: "pkg-#{initiative.number}",
                                    content_hash: "sha256:abc")
      WorkPackageRepository.create!(work_package: package,
                                    repository: repository, deploy_order: 1)
      signature = GateSignature.create!(
        initiative: initiative, work_package: package,
        package_hash: package.content_hash,
        signed_by_user: build_platform_user, identity: "Quien firma",
        signed_at: Time.current, statement: "Autorizo.")
      GateSignatureCommit.create!(gate_signature: signature,
                                  repository: repository,
                                  base_sha: "4f2a9c1", deploy_order: 1)
    end
end
