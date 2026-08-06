require "test_helper"

# La política de acceso es de MATRIX, no de la fuente que autentica.
class Platform::UserTest < ActiveSupport::TestCase
  test "entran admin y superadmin" do
    assert_predicate build_platform_user(role: :admin), :may_access_matrix?
    assert_predicate build_platform_user(role: :superadmin), :may_access_matrix?
  end

  test "marketing no entra: allí solo ve el Radar" do
    assert_not build_platform_user(role: :marketing).may_access_matrix?
  end

  test "un usuario deshabilitado en platform no entra" do
    user = build_platform_user(role: :admin, disabled: true)

    assert_not user.may_access_matrix?
  end

  test "un usuario que desapareció del origen no entra" do
    user = build_platform_user(role: :admin)
    Platform::Record.writing { user.update!(missing_since: Time.current) }

    assert_not user.may_access_matrix?
  end

  test "la identidad que se congela al firmar lleva el cargo cuando lo hay" do
    user = build_platform_user(name: "Antonio Pérez", cargo: "CTO")

    assert_equal "Antonio Pérez · CTO", user.identity_snapshot
  end
end
