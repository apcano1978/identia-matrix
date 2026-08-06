# La fuente falsa: sirve a los usuarios ya proyectados con una contraseña
# compartida de desarrollo. No hay contraseñas en matrix, así que tampoco hay
# nada que comprobar contra la base de datos — solo que quien la escribe está
# en un entorno donde eso es aceptable.
#
# Se niega a existir en producción. No es una comodidad: una fuente que deja
# entrar con una contraseña conocida no puede depender de una variable de
# entorno bien puesta.
module Auth::FakeSource
  DEFAULT_PASSWORD = "matrix".freeze

  module_function

  def authenticate(email_address:, password:)
    refuse_in_production!

    user = Platform::User.find_by(email_address: email_address)
    return Auth::Outcome.new(user: nil, error: Auth::BAD_CREDENTIALS) if user.blank?
    return Auth::Outcome.new(user: nil, error: Auth::BAD_CREDENTIALS) unless password == expected_password

    Auth::Outcome.new(user: user, error: nil)
  end

  def expected_password
    ENV.fetch("MATRIX_FAKE_AUTH_PASSWORD", DEFAULT_PASSWORD)
  end

  def refuse_in_production!
    return unless Rails.env.production?

    raise "Auth::FakeSource no puede usarse en producción"
  end
end
