require "test_helper"

# El candado entre los dos repositorios.
#
# Matrix valida lo que envía contra `agent_run.v1.json` y el brain valida lo que
# recibe contra el `config_model` Pydantic de cada agente. Son dos declaraciones
# del mismo acuerdo, escritas en lenguajes distintos y versionadas por separado:
# **pueden separarse sin que ningún test de ninguno de los dos se entere**, y el
# día que pase, el síntoma será un 422 en producción.
#
# Este test compara el esquema de matrix con el `config_schema` que el brain
# publica en `GET /v1/agents`. Solo corre si el brain está levantado y accesible:
# no puede ser un requisito de la suite —matrix se desarrolla sin brain a diario—
# pero sí tiene que correr en CI y antes de desplegar.
#
#   MATRIX_CHECK_BRAIN_CONTRACT=1 bin/rails test test/services/runtime/brain_contract_test.rb
class Runtime::BrainContractTest < ActiveSupport::TestCase
  # Lo que matrix manda en `config` y no es material del evolutivo: son
  # parámetros de llamada y ajustes propios, y el brain los declara igual.
  CALL_PARAMS = %w[model max_tokens thinking matrix].freeze

  setup do
    skip "requiere el brain levantado · MATRIX_CHECK_BRAIN_CONTRACT=1" unless enabled?
  end

  test "el esquema de matrix y el que publica el brain no han divergido" do
    publicado = brain_config_schema("matrix-tank")
    declarado = matrix_config_properties

    faltan = declarado - publicado.keys
    assert_empty faltan,
                 "matrix envía campos que el brain no declara y descartaría: #{faltan.join(', ')}"
  end

  test "lo que el brain exige, matrix lo manda siempre" do
    esquema = brain_agent_schema("matrix-tank")
    obligatorios = esquema.fetch("required", [])

    payload = Runtime::Request.for(agent_run).payload["config"]
    faltan = obligatorios - payload.keys

    assert_empty faltan, "el brain exige campos que matrix no envía: #{faltan.join(', ')}"
  end

  test "el brain publica un agente por cada uno que matrix sabe lanzar" do
    # Los que todavía corren en falso NO tienen que estar: F9 los sustituye de
    # uno en uno, y exigirlos todos convertiría este candado en un test que
    # falla por diseño hasta el último día.
    publicados = brain_agent_keys

    assert_includes publicados, "matrix-tank"
  end

  private
    def enabled? = ENV["MATRIX_CHECK_BRAIN_CONTRACT"].present?

    def matrix_config_properties
      Contracts.definition(:matrix_brain_agent_run)
               .dig("properties", "config", "properties").keys
    end

    def brain_agent_schema(key)
      agents = brain_agents
      agent = agents.find { |a| a["key"] == key }
      flunk "el brain no publica `#{key}` · registrados: #{agents.map { |a| a['key'] }.join(', ')}" if agent.nil?

      agent.fetch("config_schema")
    end

    def brain_config_schema(key) = brain_agent_schema(key).fetch("properties")

    def brain_agent_keys = brain_agents.map { |a| a["key"] }

    def brain_agents
      @brain_agents ||= begin
        response = Runtime::Brain.connection("contract-check").get("/v1/agents")
        flunk "el brain respondió #{response.status} a GET /v1/agents" unless response.status == 200

        JSON.parse(response.body).fetch("agents")
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        flunk "el brain no responde en #{ENV['AI_SERVICE_URL']}: #{e.class}"
      end
    end

    def agent_run
      AgentRun.create!(
        initiative: place(build_initiative, :tank), agent: :tank,
        purpose: :context, code: "run-#{SecureRandom.hex(4)}", status: :ok)
    end
end
