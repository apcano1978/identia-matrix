require "test_helper"

# INVARIANTES 5 y 6 · Las dos paradas obligatorias del sistema.
#
#   5 · Ninguna spec pasa a plan sin revisión de MORFEO.
#   6 · Ningún paquete llega a Claude Code sin firma que lo cubra.
#
# Van juntas porque son el mismo mecanismo: se comprueban al ENTRAR en la etapa,
# no al salir de la anterior, y así ninguna ruta las esquiva.
class TheTwoMandatoryStopsTest < ActiveSupport::TestCase
  test "sin revisión de MORFEO no se pasa a plan" do
    initiative = place(build_initiative, :morfeo)
    build_dod(initiative: initiative)

    error = assert_raises(Pipeline::PreconditionFailed) do
      Pipeline::Advance.call(initiative: initiative)
    end

    assert_match "MORFEO", error.message
    assert_predicate initiative.reload, :at_morfeo?
  end

  test "ni sin DoD ninguno" do
    initiative = place(build_initiative, :morfeo)

    assert_raises(Pipeline::PreconditionFailed) do
      Pipeline::Advance.call(initiative: initiative)
    end
  end

  test "con la revisión, sí" do
    initiative = place(build_initiative, :morfeo)
    reviewed_dod(initiative)

    Pipeline::Advance.call(initiative: initiative)

    assert_predicate initiative.reload, :at_trinity?
  end

  test "sin firma no se ejecuta" do
    initiative = place(build_initiative, :gate_1)

    error = assert_raises(Pipeline::PreconditionFailed) do
      Pipeline::Advance.call(initiative: initiative)
    end

    assert_match "sin firmar", error.message
  end

  # La parte que se olvida: una firma que existe pero no cubre el paquete
  # autoriza a escribir en un repositorio sobre el que nadie firmó.
  test "una firma que no cubre todos los repositorios del paquete tampoco vale" do
    initiative = place(build_initiative, :gate_1)
    signature = sign(initiative, repositories: 2, commits: 1)

    assert_not signature.covers_package?
    error = assert_raises(Pipeline::PreconditionFailed) do
      Pipeline::Advance.call(initiative: initiative)
    end
    assert_match "no cubre", error.message
  end

  test "cubriéndolos, sí" do
    initiative = place(build_initiative, :gate_1)
    signature = sign(initiative, repositories: 2, commits: 2)

    assert_predicate signature, :covers_package?
    Pipeline::Advance.call(initiative: initiative)

    assert_predicate initiative.reload, :at_claude_code?
  end

  private
    def reviewed_dod(initiative)
      dod = build_dod(initiative: initiative)
      dod.update!(reviewed_by_run: AgentRun.create!(
        initiative: initiative, agent: :morfeo, purpose: :review,
        code: "morfeo/#{initiative.code}", status: :ok))
      dod
    end

    def sign(initiative, repositories:, commits:)
      rows = repositories.times.map do |i|
        build_repository(client: initiative.platform_client, name: "repo-#{i}")
      end
      package = WorkPackage.create!(initiative: initiative,
                                    code: "pkg-#{initiative.number}",
                                    content_hash: "sha256:abc")
      rows.each_with_index do |repository, i|
        WorkPackageRepository.create!(work_package: package,
                                      repository: repository,
                                      deploy_order: i + 1)
      end

      signature = GateSignature.create!(
        initiative: initiative, work_package: package,
        package_hash: package.content_hash, signed_by_user: build_platform_user,
        identity: "Quien firma", signed_at: Time.current,
        statement: "Autorizo.")
      rows.first(commits).each_with_index do |repository, i|
        GateSignatureCommit.create!(gate_signature: signature,
                                    repository: repository,
                                    base_sha: "4f2a9c1", deploy_order: i + 1)
      end

      signature
    end
end
