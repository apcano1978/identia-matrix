# La costura de autenticación: el tercer sitio con este patrón, junto al runtime
# de agentes y a la proyección de platform, y por la misma razón — el endpoint
# real no existe hasta F7 y F3 necesita poder entrar antes.
#
# La fuente AUTENTICA. La política es de MATRIX, y vive en
# `Platform::User#may_access_matrix?`: solo entran `admin` y `superadmin`, y un
# usuario deshabilitado no entra. Ninguna fuente puede relajar eso.
module Auth
  # Lo que devuelve una fuente. `user` solo viene relleno si la credencial era
  # buena; que además pueda entrar lo decide matrix después.
  Outcome = Data.define(:user, :error) do
    def ok? = user.present? && error.nil?
  end

  ALLOWED = "ok".freeze
  BAD_CREDENTIALS = "bad_credentials".freeze
  NO_ACCESS = "no_access".freeze

  module_function

  def source
    case ENV.fetch("MATRIX_AUTH_SOURCE", default_source)
    when "fake" then FakeSource
    when "platform" then PlatformSource
    else
      raise ArgumentError,
            "MATRIX_AUTH_SOURCE debe ser `fake` o `platform`"
    end
  end

  def default_source = Rails.env.production? ? "platform" : "fake"

  # El único punto de entrada. Autentica contra la fuente y aplica la política
  # de matrix encima — en ese orden, y siempre las dos.
  def authenticate(email_address:, password:)
    outcome = source.authenticate(
      email_address: email_address.to_s.strip.downcase, password: password)
    return outcome unless outcome.ok?

    return outcome if outcome.user.may_access_matrix?

    Outcome.new(user: nil, error: NO_ACCESS)
  end
end
