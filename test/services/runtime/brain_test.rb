require "test_helper"

# El runtime real. Lo que se prueba aquí no es que sepa hacer un POST, sino las
# dos traducciones que importan: qué clave pide y qué pasa cuando algo va mal.
class Runtime::BrainTest < ActiveSupport::TestCase
  test "pide la clave con prefijo, que es de donde sale el feature del ledger" do
    # `agent:matrix-tank`. Sin prefijo no habría forma de separar el consumo de
    # matrix del de platform en el ledger del brain.
    pedidas = []
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/agents/matrix-tank/run") do |env|
        pedidas << env.url.path
        [ 200, {}, brain_response.to_json ]
      end
    end

    with_connection(stubs) { Runtime::Brain.run(envelope) }

    assert_equal [ "/v1/agents/matrix-tank/run" ], pedidas
  end

  test "manda la atribucion de coste en X-Feature" do
    cabeceras = {}
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/agents/matrix-tank/run") do |env|
        cabeceras = env.request_headers
        [ 200, {}, brain_response.to_json ]
      end
    end

    with_connection(stubs) { Runtime::Brain.run(envelope) }

    assert_equal "agent:matrix-tank", cabeceras["X-Feature"]
  end

  test "un 502 del brain es un error de ejecucion, no un veredicto" do
    # Que el brain falle no es un ✕, ni un `?`, ni una escalada: es que la
    # llamada no se pudo hacer. Quien lo recibe marca el run como fallido; si
    # llegara como dictamen, contaminaría el contador de ciclos de QA.
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/agents/matrix-tank/run") do
        [ 502, {}, '{"detail":"el modelo se cayó"}' ]
      end
    end

    error = assert_raises(Runtime::Error) { with_connection(stubs) { Runtime::Brain.run(envelope) } }

    assert_match "502", error.message
    assert_match "el modelo se cayó", error.message
  end

  test "que el brain no conteste es un error distinto de que conteste mal" do
    # «No responde» lo arregla alguien de sistemas y «responde mal» lo arregla
    # quien lo produjo. Si llegan iguales, la pantalla no puede decir cuál es.
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/agents/matrix-tank/run") { raise Faraday::ConnectionFailed, "nadie escucha" }
    end

    assert_raises(Runtime::Unreachable) { with_connection(stubs) { Runtime::Brain.run(envelope) } }
  end

  test "una respuesta que no es JSON no se toma por buena" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/agents/matrix-tank/run") { [ 200, {}, "<html>502 Bad Gateway</html>" ] }
    end

    assert_raises(Runtime::Unexpected) { with_connection(stubs) { Runtime::Brain.run(envelope) } }
  end

  test "la respuesta del brain se valida contra el contrato antes de persistir nada" do
    # El candado del borde: el día que un agente devuelva un veredicto inventado
    # o un tipo de hallazgo que no existe, se detecta aquí y no tres pantallas
    # más adelante, dentro de un artefacto inmutable.
    inventada = brain_response.merge("findings" => [
      { "kind" => "verdict", "statement" => "x", "verdict" => "casi" }
    ])
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/agents/matrix-tank/run") { [ 200, {}, inventada.to_json ] }
    end

    payload = with_connection(stubs) { Runtime::Brain.run(envelope) }

    refute Contracts.valid?(:matrix_brain_agent_result, payload),
           "el contrato tiene que rechazar un veredicto que no es uno de los cuatro"
  end

  private
    # Se sustituye el transporte, no la conexión: así las cabeceras y los
    # timeouts los sigue poniendo el código de producción, que es lo que estos
    # tests existen para comprobar.
    def with_connection(stubs, &block)
      with_env("AI_SERVICE_URL" => "http://brain.test", "AI_SERVICE_API_KEY" => "k") do
        Runtime::Brain.stub(:test_adapter, [ :test, stubs ], &block)
      end
    end

    def envelope
      Runtime::Request::Envelope.new(agent: "tank", purpose: "context", payload: {})
    end

    def brain_response
      {
        "contract_version" => 1, "agent" => "tank", "purpose" => "context",
        "body" => "## Qué se pide\n\nAlgo.", "citations" => [], "events" => [],
        "findings" => [],
        "usage" => { "input_tokens" => 10, "output_tokens" => 20 }
      }
    end
end
