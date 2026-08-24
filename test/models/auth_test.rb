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

  # Este test afirmaba, hasta F7, que la fuente real levantaba
  # `NotImplementedError`. Ya no: existe. Lo que sigue afirmando es que **no
  # finge**, que era lo que protegía de verdad — sin el token emitido se niega
  # a llamar a nadie en vez de devolver «no autenticado», que dejaría creer que
  # la integración está y solo falla la contraseña.
  test "la fuente real no finge funcionar sin credencial" do
    ENV.delete("PLATFORM_API_TOKEN_AUTH")

    error = assert_raises(Platform::Api::Error) do
      Auth::PlatformSource.authenticate(email_address: "a@b.com", password: "x")
    end

    assert_includes error.message, "PLATFORM_API_TOKEN_AUTH"
  end

  test "matrix no guarda contraseñas" do
    assert_not_includes Platform::User.column_names, "password_digest"
    assert_not ActiveRecord::Base.connection.table_exists?("users")
  end
end
