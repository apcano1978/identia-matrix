require "test_helper"

# La fuente autentica; la política es de matrix. Las dos, siempre, y en ese
# orden.
class AuthTest < ActiveSupport::TestCase
  test "un admin de platform entra con la contraseña de desarrollo" do
    user = build_platform_user(role: :admin)

    outcome = Auth.authenticate(email_address: user.email_address,
                                password: Auth::FakeSource::DEFAULT_PASSWORD)

    assert_predicate outcome, :ok?
    assert_equal user, outcome.user
  end

  test "una credencial mala no entra" do
    user = build_platform_user(role: :admin)

    outcome = Auth.authenticate(email_address: user.email_address,
                                password: "otra")

    assert_not outcome.ok?
    assert_equal Auth::BAD_CREDENTIALS, outcome.error
  end

  test "marketing autentica bien y aun así no entra: la política es de matrix" do
    user = build_platform_user(role: :marketing)

    outcome = Auth.authenticate(email_address: user.email_address,
                                password: Auth::FakeSource::DEFAULT_PASSWORD)

    assert_not outcome.ok?
    assert_equal Auth::NO_ACCESS, outcome.error
  end

  test "un deshabilitado tampoco, y se distingue de una credencial mala" do
    user = build_platform_user(role: :admin, disabled: true)

    outcome = Auth.authenticate(email_address: user.email_address,
                                password: Auth::FakeSource::DEFAULT_PASSWORD)

    assert_equal Auth::NO_ACCESS, outcome.error
  end

  test "el correo se normaliza antes de buscar" do
    user = build_platform_user(email_address: "antonio@identiaconsulting.com")

    outcome = Auth.authenticate(email_address: "  Antonio@IdentiaConsulting.com ",
                                password: Auth::FakeSource::DEFAULT_PASSWORD)

    assert_equal user, outcome.user
  end

  test "la fuente real no finge funcionar: llega en F7" do
    assert_raises(NotImplementedError) do
      Auth::PlatformSource.authenticate(email_address: "a@b.com", password: "x")
    end
  end

  test "matrix no guarda contraseñas" do
    assert_not_includes Platform::User.column_names, "password_digest"
    assert_not ActiveRecord::Base.connection.table_exists?("users")
  end
end
