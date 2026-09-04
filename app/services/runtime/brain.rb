# El runtime real: `POST /v1/agents/{key}/run` contra identia-brain.
#
# Mismo patrón que `Platform::Api`, que es el otro cliente HTTP de matrix, con
# una diferencia que importa: los timeouts. Platform contesta un índice en
# milisegundos y por eso allí son de segundos; aquí al otro lado hay un modelo
# escribiendo un artefacto entero, y un TANK sobre nueve fuentes tarda minutos.
#
# ⚠ El timeout no se elige solo. Vive dentro de una jerarquía que empieza en el
# dispatcher de platform y acaba en la síntesis del brain, documentada en
# `identia-platform/app/services/ai/client.rb` y en `config.py` del brain:
#
#   AI_SERVICE_TIMEOUT (900 s) > turn_budget_seconds (700 s) > síntesis (540 s)
#
# Matrix elige el suyo DENTRO de esa jerarquía y por encima del presupuesto de
# turno: si esperase menos, cortaría por fuera una ejecución que el brain sigue
# pagando, y ese es el peor sitio donde cortar.
module Runtime::Brain
  # Por debajo de los 900 s de platform y por encima de los 700 s del turno.
  TIMEOUT = 780
  OPEN_TIMEOUT = 10

  # Las claves de matrix en el brain llevan prefijo. No es higiene de nombres:
  # el `feature` del ledger se deriva de la clave, y `GET /v1/usage?feature=`
  # filtra POR PREFIJO, así que `agent:matrix-` da el consumo de matrix entero
  # en una consulta. Sin prefijo no habría forma de separarlo del de platform.
  KEY_PREFIX = "matrix-".freeze

  module_function

  def run(request)
    key = "#{KEY_PREFIX}#{request.agent}"
    response = post("/v1/agents/#{key}/run", request.payload, feature: "agent:#{key}")

    return response.body if response.status == 200

    # Un fallo del brain NO es un veredicto. Que responda 502 no es un ✕, ni un
    # `?`, ni una escalada: es que la llamada no se pudo hacer. Quien lo recibe
    # marca el run como fallido y para; confundirlo con un dictamen contaminaría
    # el contador de ciclos de QA, que es lo que protege el invariante 7.
    raise Runtime::Error,
          "el brain respondió #{response.status} ejecutando #{key}: #{detail(response.body)}"
  end

  def post(path, payload, feature:)
    raw = connection(feature).post(path, payload.to_json)
    Response.new(status: raw.status, body: parse(raw.body))
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    # Separado de una respuesta mala por la misma razón que en `Platform::Api`:
    # «el brain no contesta» lo arregla alguien de sistemas y «la respuesta no
    # vale» lo arregla quien la produjo. Si llegan iguales, la pantalla no puede
    # decir cuál de las dos es.
    raise Runtime::Unreachable, "identia-brain no responde: #{e.class}"
  end

  Response = Data.define(:status, :body)

  def detail(body)
    return body.to_s.truncate(200) unless body.is_a?(Hash)

    body["detail"].presence || body.to_json.truncate(200)
  end

  def parse(body)
    return {} if body.blank?

    JSON.parse(body)
  rescue JSON::ParserError
    raise Runtime::Unexpected, "identia-brain devolvió algo que no es JSON"
  end

  def connection(feature)
    base_url = ENV.fetch("AI_SERVICE_URL", nil)
    api_key = ENV.fetch("AI_SERVICE_API_KEY", nil)

    raise Runtime::Error, "falta AI_SERVICE_URL" if base_url.blank?
    raise Runtime::Error, "falta AI_SERVICE_API_KEY" if api_key.blank?

    Faraday.new(url: base_url) do |f|
      f.headers["Authorization"] = "Bearer #{api_key}"
      f.headers["Content-Type"] = "application/json"
      f.headers["Accept"] = "application/json"
      # La atribución de coste en el ledger del brain. El consumidor lo resuelve
      # él por la clave; esto dice para qué.
      f.headers["X-Feature"] = feature
      f.options.open_timeout = OPEN_TIMEOUT
      f.options.timeout = Integer(ENV.fetch("MATRIX_BRAIN_TIMEOUT", TIMEOUT))

      adapter = test_adapter
      f.adapter(*adapter) if adapter
    end
  end

  # Solo se sustituye en los tests, y solo el TRANSPORTE. La alternativa era
  # inyectar la conexión entera —como hace `Platform::Api`—, pero entonces las
  # cabeceras las construiría el test y no este fichero, y justo `X-Feature` es
  # una de las cosas que hay que comprobar que salen bien de aquí.
  def test_adapter = nil
end
