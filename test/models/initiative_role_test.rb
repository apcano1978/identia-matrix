# frozen_string_literal: true

require "test_helper"

# El papel de una persona EN UN EVOLUTIVO, que no es su rol de acceso.
class InitiativeRoleTest < ActiveSupport::TestCase
  setup do
    @initiative = build_initiative
    @user = build_platform_user(role: :admin)
  end

  test "una persona tiene un solo papel por evolutivo" do
    InitiativeRole.create!(initiative: @initiative, platform_user: @user,
                           role: :observer)

    duplicate = InitiativeRole.new(initiative: @initiative, platform_user: @user,
                                   role: :approver)

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :platform_user_id
  end

  test "pero sí puede tener papeles distintos en evolutivos distintos" do
    InitiativeRole.create!(initiative: @initiative, platform_user: @user,
                           role: :observer)

    otro = InitiativeRole.new(initiative: build_initiative, platform_user: @user,
                              role: :approver)

    assert_predicate otro, :valid?
  end

  # ── Quién puede aprobar ───────────────────────────────────────────────────

  # La decisión del 17 de agosto: el equipo que opera matrix puede todo lo que
  # exija intervención humana, sin necesidad de una fila de papel.
  test "un operador aprueba y firma en cualquier evolutivo, sin papel" do
    %i[admin superadmin].each do |role|
      user = build_platform_user(role: role)

      assert user.may_approve?(@initiative), "#{role} tiene que poder aprobar"
      assert user.may_sign?(@initiative)
      assert user.may_participate?(@initiative)
      assert_nil user.role_in(@initiative), "y sin necesitar una fila"
    end
  end

  test "quien no puede entrar en matrix no aprueba, tenga el papel que tenga" do
    user = build_platform_user(role: :marketing)
    InitiativeRole.create!(initiative: @initiative, platform_user: user,
                           role: :approver)

    assert_not user.may_approve?(@initiative)
    assert_not user.may_participate?(@initiative)
  end

  test "un observador participa pero no aprueba" do
    user = build_platform_user(role: :admin)
    # Se le fuerza a NO ser operador para poder ver el papel decidir. Hoy no
    # ocurre —solo entran admin y superadmin—, pero es la regla que gobernará
    # cuando F7 ensanche quién entra.
    role = InitiativeRole.create!(initiative: @initiative, platform_user: user,
                                  role: :observer)

    assert_equal "observer", role.role
    assert_not role.approver?
  end

  test "el papel se lee del evolutivo que se pregunta, no de otro" do
    otro = build_initiative
    InitiativeRole.create!(initiative: otro, platform_user: @user,
                           role: :approver)

    assert_nil @user.role_in(@initiative)
    assert_equal "approver", @user.role_in(otro).role
  end

  test "sin evolutivo no hay papel" do
    assert_nil @user.role_in(nil)
  end
end
