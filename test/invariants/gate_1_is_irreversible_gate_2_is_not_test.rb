require "test_helper"

# INVARIANTE 9 · GATE 1 es irreversible; GATE 2 no.
#
# La asimetría es del modelo, no de la interfaz. GATE 1 AUTORIZA a ejecutar, y
# lo ejecutado no se desejecuta. GATE 2 CONFIRMA que lo ejecutado sirve, y eso
# se puede volver a mirar.
class Gate1IsIrreversibleGate2IsNotTest < ActiveSupport::TestCase
  setup { DesignSeed.call }

  test "una firma no se edita ni se borra" do
    signature = GateSignature.sole

    assert_raises(ActiveRecord::ReadOnlyRecord) { signature.update!(identity: "Otro") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { signature.destroy }
    assert GateSignature.exists?(signature.id)
  end

  test "y borrar sus commits no la deja abierta" do
    signature = GateSignature.sole
    signature.gate_signature_commits.destroy_all

    assert_raises(ActiveRecord::ReadOnlyRecord) { signature.destroy }
  end

  test "un paquete se firma una sola vez" do
    signature = GateSignature.sole
    second = GateSignature.new(signature.attributes.except("id", "created_at",
                                                           "updated_at"))

    assert_not second.valid?
  end

  test "un multi-repo sin orden de despliegue no se puede firmar" do
    initiative = Initiative.find_by!(code: "ev-031")
    package = WorkPackage.create!(initiative: initiative, code: "pkg-sin-orden",
                                  content_hash: "sha256:abc")
    signature = GateSignature.new(
      initiative: initiative, work_package: package, package_hash: "sha256:abc",
      signed_by_user: Platform::User.first, identity: "Quien firma",
      signed_at: Time.current, statement: "Autorizo.")

    assert_not signature.valid?
    assert_includes signature.errors.attribute_names, :work_package
  end

  test "la identidad queda congelada aunque el usuario cambie en platform" do
    signature = GateSignature.sole
    frozen = signature.identity

    Platform::Record.writing do
      signature.signed_by_user.update!(name: "Otro Nombre", cargo: "CEO")
    end

    assert_equal frozen, signature.reload.identity
    assert_not_equal signature.signed_by_user.identity_snapshot, frozen
  end

  # GATE 2, en cambio, acumula decisiones: un evolutivo rechazado y vuelto a
  # validar tiene dos, y las dos se conservan.
  test "GATE 2 admite varias decisiones y el rechazo devuelve a NEO" do
    guide = TestGuide.find_by!(code: "guia-pruebas-031")
    initiative = place(guide.initiative, :gate_2)

    GateValidation.create!(initiative: initiative, test_guide: guide,
                           decision: :rejected, rejection_note: "No sirve",
                           decided_by_user: Platform::User.first,
                           decided_at: Time.current)
    Pipeline::SendBack.call(initiative: initiative, to: :neo, actor: "Antonio")
    GateValidation.create!(initiative: initiative, test_guide: guide,
                           decision: :validated,
                           decided_by_user: Platform::User.first,
                           decided_at: Time.current)

    assert_equal 2, initiative.gate_validations.count
    assert_predicate initiative.reload, :at_neo?
  end

  test "sin índice único: la asimetría también está en el esquema" do
    unique = ActiveRecord::Base.connection.indexes(:gate_validations)
                               .select(&:unique).flat_map(&:columns)

    assert_not_includes unique, "initiative_id"
    assert ActiveRecord::Base.connection.indexes(:gate_signatures)
                             .any? { |i| i.unique && i.columns == [ "work_package_id" ] }
  end
end
