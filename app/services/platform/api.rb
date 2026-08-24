# El cliente HTTP contra la API interna de identia-platform.
#
# **Un token por sujeto, no uno por aplicación.** Cada quien lleva el suyo, con
# los scopes que necesita y ninguno más: si el de la sincronización se filtrara,
# no debe servir para probar contraseñas contra platform. Por eso se entra por
# `Platform::Api.for(:auth)` y no por `new(token: …)` — el sujeto se nombra, no
# se pasa a mano desde cualquier sitio.
#
# Lo estrena F7 con la autenticación; F8 lo reutiliza para la sincronización.
class Platform::Api
  Error       = Class.new(StandardError)
  Unreachable = Class.new(Error)
  Unexpected  = Class.new(Error)

  # De qué variable sale el token de cada sujeto. Los emite platform con
  # `rake matrix:issue_token[matrix:auth]`.
  SUBJECTS = {
    auth:   "PLATFORM_API_TOKEN_AUTH",
    system: "PLATFORM_API_TOKEN_SYSTEM",
    tank:   "PLATFORM_API_TOKEN_TANK"
  }.freeze

  # Cortos a propósito: platform está al otro lado de `host.docker.internal` en
  # desarrollo y del bridge en producción, no de internet. Si tarda más que
  # esto, algo pasa y la pantalla de login tiene que decirlo, no colgarse.
  OPEN_TIMEOUT = 2
  TIMEOUT      = 5

  Response = Data.define(:status, :body) do
    def ok?           = status == 200
    def unauthorized? = status == 401
    def forbidden?    = status == 403
  end

  def self.for(subject)
    var = SUBJECTS.fetch(subject) { raise ArgumentError, "sujeto desconocido: #{subject.inspect}" }
    token = ENV[var]

    raise Error, "falta #{var}: el token de `matrix:#{subject}` lo emite platform" if token.blank?

    new(token: token)
  end

  # `connection` se inyecta solo en los tests, con el adaptador de prueba de
  # Faraday. No es una comodidad: la alternativa es levantar platform para
  # comprobar que un 401 se traduce a un 401.
  def initialize(token:, base_url: ENV.fetch("PLATFORM_API_URL", nil), connection: nil)
    raise Error, "falta PLATFORM_API_URL" if base_url.blank? && connection.nil?

    @token      = token
    @base_url   = base_url
    @connection = connection
  end

  def post(path, body)
    request(:post) { |conn| conn.post(url_for(path), body.to_json) }
  end

  def get(path, params = {})
    request(:get) { |conn| conn.get(url_for(path), params) }
  end

  private

  attr_reader :token, :base_url

  def url_for(path) = "/internal/v1/#{path}"

  def request(verb)
    raw = yield(connection)
    Response.new(status: raw.status, body: parse(raw.body))
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    # Se distingue de una respuesta mala a propósito: «platform no contesta» lo
    # arregla alguien de sistemas y «no eres tú» lo arregla la persona. Que la
    # pantalla pueda decir cuál es requiere que lleguen distintas hasta aquí.
    raise Unreachable, "platform no responde (#{verb.to_s.upcase}): #{e.class}"
  end

  def parse(body)
    return {} if body.blank?

    JSON.parse(body)
  rescue JSON::ParserError
    raise Unexpected, "platform devolvió algo que no es JSON"
  end

  def connection
    @connection ||= Faraday.new(url: base_url) do |f|
      f.headers["Authorization"] = "Bearer #{token}"
      f.headers["Content-Type"]  = "application/json"
      f.headers["Accept"]        = "application/json"
      f.options.open_timeout     = OPEN_TIMEOUT
      f.options.timeout          = TIMEOUT
    end
  end
end
