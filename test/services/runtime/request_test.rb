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

  test "la configuración efectiva del agente viaja en la petición" do
    run = agent_run
    AgentConfig.create!(agent: run.agent, settings: { "max_tokens" => 8000 })
    AgentConfig.create!(agent: run.agent,
                        platform_client_id: run.initiative.platform_client_id,
                        settings: { "thinking" => "adaptive" })

    config = Runtime::Request.for(run).payload["config"]

    assert_equal 8000, config["max_tokens"]
    assert_equal "adaptive", config["thinking"]
    assert_equal Runtime::Request::DEFAULT_MODEL, config["model"]
  end

  private
    def agent_run
      @agent_run ||= AgentRun.create!(
        initiative: place(build_initiative, :tank), agent: :tank,
        purpose: :context, code: "run-#{SecureRandom.hex(4)}", status: :running)
    end
end
