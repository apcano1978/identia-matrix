# La fuente real: valida la credencial contra identia-platform, por
# `POST /internal/v1/authenticate` con el token del sujeto `matrix:auth`.
#
# **Platform autentica; matrix decide.** El endpoint contesta «esta contraseña
# es de esta persona, y su rol es este»; quién entra en matrix lo resuelve
# `Auth.authenticate` con `may_access_matrix?`, y esa regla no viaja al otro
# repositorio.
module Auth::PlatformSource
  module_function

  def authenticate(email_address:, password:)
    response = api.post("authenticate",
                        email_address: email_address, password: password)

    return no(Auth::BAD_CREDENTIALS) if response.unauthorized?
    raise Platform::Api::Unexpected, "authenticate devolvió #{response.status}" unless response.ok?

    resolve(response.body.fetch("user"))
  end

  # La contraseña la verifica platform; **quién es esa persona aquí lo dice la
  # proyección**. Un correo que no esté proyectado no entra aunque acierte:
  # matrix no da de alta usuarios al vuelo, y hacerlo convertiría el login en
  # una escritura — la aplicación no tiene ni un `update`.
  #
  # No se refresca nada de la fila con lo que acaba de contestar platform. Eso
  # es sincronización, es de F8, y hacerlo aquí metería una escritura en el
  # camino del login.
  def resolve(attrs)
    user = Platform::User.find_by(platform_id: attrs["platform_id"])
    return no(Auth::NO_ACCESS) if user.nil?

    # El rol recién contestado manda sobre el proyectado. La proyección puede
    # estar vieja —se sincroniza cada tanto—, y quien fue degradado en platform
    # esta mañana no debería seguir entrando esta tarde. Las dos condiciones se
    # exigen: `Auth.authenticate` comprueba la fila después de esto.
    return no(Auth::NO_ACCESS) unless Platform::User::ROLES_WITH_ACCESS.include?(attrs["role"])

    Auth::Outcome.new(user: user, error: nil)
  end

  def no(error) = Auth::Outcome.new(user: nil, error: error)

  def api = Platform::Api.for(:auth)
end
