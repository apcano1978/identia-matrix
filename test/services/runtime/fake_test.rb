require "test_helper"

class Runtime::FakeTest < ActiveSupport::TestCase
  # La razón de ser del bloque: un falso que devuelve algo que el contrato no
  # acepta no prueba nada.
  test "todos los fixtures pasan el contrato de resultado" do
    Runtime::Fixture.available.each do |agent, purpose|
      payload = Runtime::Fake.run(request_for(agent, purpose))

      assert_empty Contracts.errors(:matrix_brain_agent_result, payload),
                   "#{agent}/#{purpose} no cabe en agent_result.v1.json"
    end
  end

  test "la ejecución completa devuelve un resultado ya validado" do
    result = Runtime.run(agent_run(agent: :seraph, purpose: :verification))

    assert_equal "seraph", result.agent
    assert_equal 3, result.verdicts.size
    assert_equal %w[unsupported met met], result.verdicts.map { |v| v["verdict"] }
    assert_predicate result.output_tokens, :positive?
  end

  test "morfeo devuelve bloqueantes, y el bloqueante dice de quién es" do
    result = Runtime.run(agent_run(agent: :morfeo, purpose: :review))

    assert_equal 1, result.blockers.size
    assert_equal "c0", result.blockers.first["reference"]
  end

  test "el cuerpo habla del evolutivo sobre el que se ejecutó" do
    run = agent_run(agent: :tank, purpose: :context)

    body = Runtime.run(run).body

    assert_includes body, run.initiative.code
    assert_includes body, run.initiative.platform_client.slug
    assert_not_includes body, "{{initiative}}"
  end

  test "sin retardo en test" do
    elapsed = Benchmark.realtime { Runtime.run(agent_run) }

    assert_operator elapsed, :<, 0.5
  end

  test "el runtime se elige con la variable de entorno" do
    assert_equal Runtime::Fake, Runtime.implementation

    with_env("MATRIX_AGENT_RUNTIME" => "brain") do
      assert_equal Runtime::Brain, Runtime.implementation
    end

    with_env("MATRIX_AGENT_RUNTIME" => "inventado") do
      assert_raises(ArgumentError) { Runtime.implementation }
    end
  end

  # Este test decía «el runtime real no finge funcionar: llega en F9», y llegó.
  # Lo que sigue siendo cierto —y merece guarda— es que no salga a la red sin
  # saber a dónde: un `AI_SERVICE_URL` vacío tiene que fallar diciéndolo, no
  # intentar hablar con nadie.
  test "el runtime real no sale a la red sin saber a donde" do
    with_env("AI_SERVICE_URL" => nil, "AI_SERVICE_API_KEY" => "k") do
      error = assert_raises(Runtime::Error) { Runtime::Brain.connection("agent:matrix-tank") }
      assert_match "AI_SERVICE_URL", error.message
    end

    with_env("AI_SERVICE_URL" => "http://brain.test", "AI_SERVICE_API_KEY" => nil) do
      error = assert_raises(Runtime::Error) { Runtime::Brain.connection("agent:matrix-tank") }
      assert_match "AI_SERVICE_API_KEY", error.message
    end
  end

  private
    def agent_run(agent: :tank, purpose: :context)
      initiative = build_initiative
      place(initiative, Pipeline::STAGE_WORK.find { |_, w|
        w[:agent] == agent.to_s && w[:purpose] == purpose.to_s
      }.first)

      AgentRun.create!(initiative: initiative, agent: agent, purpose: purpose,
                       code: "run-#{SecureRandom.hex(4)}", status: :running)
    end

    def request_for(agent, purpose)
      Runtime::Request.for(agent_run(agent: agent, purpose: purpose))
    end
end
