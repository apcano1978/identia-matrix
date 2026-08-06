require "test_helper"

# La petición se valida también con el falso. Es la única forma de saber que lo
# que matrix construye cabe en el contrato antes de que exista el otro extremo.
class Runtime::RequestTest < ActiveSupport::TestCase
  test "la petición cabe en agent_run.v1.json" do
    envelope = Runtime::Request.for(agent_run)

    assert_empty Contracts.errors(:matrix_brain_agent_run, envelope.payload)
    assert_equal "tank", envelope.agent
  end

  test "lleva la frontera de cliente dentro" do
    run = agent_run
    payload = Runtime::Request.for(run).payload

    assert_equal run.initiative.platform_client.slug,
                 payload.dig("context", "client", "slug")
  end

  test "solo viajan los repositorios anclados" do
    run = agent_run
    client = run.initiative.platform_client
    InitiativeRepository.create!(
      initiative: run.initiative,
      repository: build_repository(client: client, name: "booking-core"),
      pinned_sha: "4f2a9c1")
    InitiativeRepository.create!(
      initiative: run.initiative,
      repository: build_repository(client: client, name: "owner-web"))

    repositories = Runtime::Request.for(run).payload.dig("context", "repositories")

    assert_equal [ "booking-core" ], repositories.map { |r| r["name"] }
  end

  test "la configuración efectiva del agente viaja aparte, bajo `matrix`" do
    run = agent_run
    AgentConfig.create!(agent: run.agent,
                        settings: { "model" => { "engine" => "sonnet" } })
    AgentConfig.create!(agent: run.agent,
                        platform_client_id: run.initiative.platform_client_id,
                        settings: { "model" => { "spec_length" => "verbose" } })

    config = Runtime::Request.for(run).payload["config"]

    assert_equal({ "engine" => "sonnet", "spec_length" => "verbose" },
                 config.dig("matrix", "model"))
  end

  # El vocabulario de matrix y el del contrato comparten la palabra `model` y
  # significan cosas distintas. Cuando se mezclaban, una sección llamada así
  # pisaba el alias y la petición dejaba de validar.
  test "y no pisa el alias de modelo del contrato" do
    run = agent_run
    AgentConfig.create!(agent: run.agent,
                        settings: { "model" => { "engine" => "sonnet" } })
    envelope = Runtime::Request.for(run)

    assert_equal Runtime::Request::DEFAULT_MODEL, envelope.payload.dig("config", "model")
    assert_empty Contracts.errors(:matrix_brain_agent_run, envelope.payload)
  end

  private
    def agent_run
      @agent_run ||= AgentRun.create!(
        initiative: place(build_initiative, :tank), agent: :tank,
        purpose: :context, code: "run-#{SecureRandom.hex(4)}", status: :running)
    end
end
