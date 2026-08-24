require "test_helper"

# La fuente real de F7. Lo que se prueba aquí no es el HTTP —eso es
# `Platform::ApiTest`— sino el reparto de responsabilidad: platform dice si la
# contraseña es esa; quién entra en matrix lo decide matrix.
class Auth::PlatformSourceTest < ActiveSupport::TestCase
  include DomainBuilders

  # Un doble de `Platform::Api` que devuelve lo que se le diga.
  Api = Struct.new(:response) do
    def post(_path, _body) = response
  end

  def responding(status, body = {})
    Api.new(Platform::Api::Response.new(status: status, body: body))
  end

  def authenticating_with(api, email:, password: "da igual")
    Platform::Api.stub(:for, api) do
      Auth::PlatformSource.authenticate(email_address: email, password: password)
    end
  end

  def user_payload(user, role: user.role)
    { "user" => { "platform_id" => user.platform_id, "email_address" => user.email_address,
                  "name" => user.name, "role" => role, "cargo" => nil } }
  end

  test "una contraseña buena devuelve al usuario proyectado" do
    user = build_platform_user(role: :admin)

    outcome = authenticating_with(responding(200, user_payload(user)),
                                  email: user.email_address)

    assert outcome.ok?
    assert_equal user, outcome.user
  end

  test "un 401 de platform es una credencial mala" do
    outcome = authenticating_with(responding(401, { "error" => "credenciales inválidas" }),
                                  email: "quien@sea.com")

    assert_not outcome.ok?
    assert_equal Auth::BAD_CREDENTIALS, outcome.error
  end

  test "acertar la contraseña sin estar proyectado NO entra" do
    # Matrix no da de alta usuarios al vuelo: el login no escribe.
    payload = { "user" => { "platform_id" => 999_999, "email_address" => "nueva@identia.com",
                            "name" => "Nueva", "role" => "admin", "cargo" => nil } }

    outcome = authenticating_with(responding(200, payload), email: "nueva@identia.com")

    assert_not outcome.ok?
    assert_equal Auth::NO_ACCESS, outcome.error
    assert_nil Platform::User.find_by(platform_id: 999_999), "no debería haber creado nada"
  end

  test "el rol que acaba de contestar platform manda sobre el proyectado" do
    # Proyectada como admin, degradada esta mañana en platform. La proyección
    # todavía no lo sabe —eso lo arregla la sincronización de F8— y aun así no
    # debería entrar.
    user = build_platform_user(role: :admin)

    outcome = authenticating_with(responding(200, user_payload(user, role: "marketing")),
                                  email: user.email_address)

    assert_not outcome.ok?
    assert_equal Auth::NO_ACCESS, outcome.error
  end

  test "una respuesta inesperada revienta en vez de dejar pasar" do
    user = build_platform_user

    assert_raises(Platform::Api::Unexpected) do
      authenticating_with(responding(500, {}), email: user.email_address)
    end
  end

  # `Auth.authenticate` aplica la política ENCIMA de la fuente. Que las dos
  # capas se exijan, y no una u otra, es lo que hace que ninguna fuente pueda
  # relajar la regla de matrix.
  test "la política de matrix sigue aplicándose sobre la fuente real" do
    user = build_platform_user(role: :admin, disabled: true)

    outcome = with_auth_source("platform") do
      Platform::Api.stub(:for, responding(200, user_payload(user))) do
        Auth.authenticate(email_address: user.email_address, password: "x")
      end
    end

    assert_not outcome.ok?
    assert_equal Auth::NO_ACCESS, outcome.error
  end

  private

  def with_auth_source(source)
    previo = ENV["MATRIX_AUTH_SOURCE"]
    ENV["MATRIX_AUTH_SOURCE"] = source
    yield
  ensure
    ENV["MATRIX_AUTH_SOURCE"] = previo
  end
end
