require "test_helper"

# GATE 1 es irreversible y GATE 2 no. Esa asimetría está en el modelo.
class GateSignatureTest < ActiveSupport::TestCase
  test "una firma no se edita" do
    assert_raises(ActiveRecord::ReadOnlyRecord) do
      signature.update!(statement: "Otra cosa")
    end
  end

  test "una firma no se borra" do
    firmada = signature

    assert_raises(ActiveRecord::ReadOnlyRecord) { firmada.destroy }
    assert GateSignature.exists?(firmada.id)
  end

  test "un paquete se firma una sola vez" do
    firmada = signature
    segunda = GateSignature.new(
      initiative: firmada.initiative, work_package: firmada.work_package,
      package_hash: "otro", signed_by_user: build_platform_user,
      identity: "Otra persona", signed_at: Time.current, statement: "Firmo")

    assert_not segunda.valid?
  end

  test "GATE 2 sí admite varias decisiones: un rechazo no cierra la puerta" do
    guide = test_guide
    2.times do |i|
      GateValidation.create!(
        initiative: guide.initiative, test_guide: guide,
        decision: :rejected, rejection_note: "Falla el paso #{i}",
        decided_by_user: build_platform_user, decided_at: Time.current)
    end

    assert_equal 2, guide.initiative.gate_validations.count
  end

  test "un rechazo sin motivo escrito es un rechazo que nadie puede atender" do
    guide = test_guide
    rechazo = GateValidation.new(
      initiative: guide.initiative, test_guide: guide, decision: :rejected,
      decided_by_user: build_platform_user, decided_at: Time.current)

    assert_not rechazo.valid?
    assert_includes rechazo.errors.attribute_names, :rejection_note
  end

  test "un paquete multi-repo sin orden de despliegue está incompleto" do
    initiative = build_initiative
    package = WorkPackage.create!(initiative: initiative, code: "pkg-045")

    assert_not package.deploy_order_complete?

    2.times do |i|
      WorkPackageRepository.create!(
        work_package: package,
        repository: build_repository(client: initiative.platform_client,
                                     name: "repo-#{i}"),
        deploy_order: i + 1)
    end

    assert package.reload.deploy_order_complete?
    assert_equal [ 1, 2 ], package.deploy_sequence.map(&:deploy_order)
  end

  private
    def signature
      @signature ||= begin
        initiative = build_initiative
        package = WorkPackage.create!(initiative: initiative, code: "pkg-045",
                                      sealed_at: Time.current,
                                      content_hash: "sha256:abc")
        # Sin orden de despliegue no se puede firmar: es el invariante 9.
        WorkPackageRepository.create!(
          work_package: package,
          repository: build_repository(client: initiative.platform_client),
          deploy_order: 1)
        GateSignature.create!(
          initiative: initiative, work_package: package,
          package_hash: package.content_hash,
          signed_by_user: build_platform_user, identity: "Antonio Pérez · CTO",
          signed_at: Time.current,
          statement: "Autorizo ejecutar pkg-045 sobre identia-platform.")
      end
    end

    def test_guide
      @test_guide ||= begin
        report = build_report(outcome: :conforme)
        TestGuide.create!(initiative: report.initiative,
                          verification_report: report,
                          code: "guia-pruebas-#{report.initiative.number}")
      end
    end
end
