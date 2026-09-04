# La costura de ejecución de agentes. Dos implementaciones con la misma
# interfaz, elegidas con `MATRIX_AGENT_RUNTIME=fake|brain`:
#
#   Runtime::Fake    devuelve markdown de fixture. Existe desde F2.
#   Runtime::Brain   habla con identia-brain por HTTP. Llega en F9.
#
# La regla que hace que esto sirva para algo: **el falso se valida contra el
# mismo contrato que el real**. Un runtime falso que devuelve algo que
# `agent_result.v1.json` no acepta no prueba nada — el día que se enchufe el
# brain, todo lo construido encima se cae de golpe.
module Runtime
  # Lo que devuelve una ejecución, ya validado contra el contrato.
  Result = Data.define(:agent, :purpose, :body, :citations, :events, :findings,
                       :usage, :request_id) do
    def input_tokens = usage["input_tokens"].to_i
    def output_tokens = usage["output_tokens"].to_i

    def verdicts = findings.select { |f| f["kind"] == "verdict" }
    def blockers = findings.select { |f| f["kind"] == "blocking" }
  end

  class Error < StandardError; end
  class MissingFixture < Error; end
  # «El brain no contesta» y «el brain contestó algo que no vale» son dos
  # averías distintas, las arregla gente distinta, y llegan separadas para que
  # la pantalla pueda decir cuál es.
  class Unreachable < Error; end
  class Unexpected < Error; end

  # Los agentes que YA existen en identia-brain. Crece de uno en uno, en orden de
  # pipeline: TANK → NEO → SERAPH → MORFEO → TRINITY → LINK.
  #
  # Sin esta lista, `MATRIX_AGENT_RUNTIME=brain` sería todo o nada, y F9 no se
  # podría hacer por partes: en cuanto TANK fuera real, lanzar NEO pediría al
  # brain una clave que todavía no tiene registrada y devolvería un 404. La
  # gracia de sustituirlos uno a uno es que la cabeza del flujo sea real y la
  # cola siga siendo de fixture **sin que el pipeline lo note**.
  #
  # Que un agente esté aquí y no en el brain lo detecta el test de contrato
  # (`test/services/runtime/brain_contract_test.rb`), no un 404 en producción.
  BRAIN_AGENTS = %w[tank].freeze

  module_function

  # El runtime de UN agente. `brain` es el techo, no la orden: pide el real solo
  # para los que existen y deja en falso al resto.
  def implementation(agent = nil)
    case ENV.fetch("MATRIX_AGENT_RUNTIME", "fake")
    when "fake" then Fake
    when "brain" then real?(agent) ? Brain : Fake
    else
      raise ArgumentError, "MATRIX_AGENT_RUNTIME debe ser `fake` o `brain`"
    end
  end

  def real?(agent) = BRAIN_AGENTS.include?(agent.to_s)

  # El único punto de entrada. Construye la petición, la valida, ejecuta y
  # valida la respuesta — las dos validaciones siempre, con los dos runtimes.
  def run(agent_run)
    request = Request.for(agent_run)
    payload = implementation(agent_run.agent).run(request)

    Contracts.validate!(:matrix_brain_agent_result, payload)
    build_result(payload)
  end

  def build_result(payload)
    payload = payload.deep_stringify_keys

    Result.new(
      agent: payload["agent"], purpose: payload["purpose"],
      body: payload["body"], citations: payload.fetch("citations", []),
      events: payload.fetch("events", []),
      findings: payload.fetch("findings", []),
      usage: payload["usage"], request_id: payload["request_id"])
  end
end
