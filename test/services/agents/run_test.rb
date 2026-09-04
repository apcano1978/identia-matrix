require "test_helper"

# Ejecutar un agente y dejar constancia. Lo que se prueba aquí son las dos
# propiedades que el sistema no puede perder: que un fallo técnico no se
# confunda con un veredicto, y que dos lanzamientos simultáneos no produzcan
# dos ejecuciones.
class Agents::RunTest < ActiveSupport::TestCase
  test "una ejecucion correcta registra el consumo y publica el artefacto" do
    initiative = initiative_ready_for_tank

    outcome = Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)

    assert_equal "ok", outcome.agent_run.status
    assert_predicate outcome.agent_run.finished_at, :present?
    assert_equal :dossier, outcome.artifact.kind.to_sym
    assert_equal outcome.agent_run, outcome.artifact.produced_by_run
  end

  # ── Criterio 7 · lo impide la base de datos, no el controlador ───────────

  test "dos lanzamientos del mismo agente: el segundo lo rechaza el indice unico" do
    # La interfaz, un relanzamiento manual y el reintento de un job pueden
    # solaparse. Una comprobación en Ruby tiene una ventana entre el `exists?` y
    # el `create`; el índice único parcial no la tiene.
    initiative = place(build_initiative, :tank)
    AgentRun.create!(initiative: initiative, agent: :tank, purpose: :context,
                     iteration: initiative.iteration, code: "run-vivo",
                     status: :running, started_at: Time.current)

    assert_raises(Agents::Run::AlreadyRunning) do
      Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)
    end
  end

  test "una ejecucion TERMINADA no impide volver a lanzar" do
    # El índice es parcial: solo `queued` y `running`. Si cubriera todo, un
    # agente no podría ejecutarse dos veces en la vida de un evolutivo.
    initiative = initiative_ready_for_tank
    Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)
       .agent_run.update!(iteration: 0)

    assert_nothing_raised do
      Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)
    end
  end

  # ── Criterio 8 · un fallo técnico no es un veredicto ─────────────────────

  test "un fallo del brain deja el run en failed y NO consume ciclo de QA" do
    # Que el brain responda 502 no es un ✕: es que la llamada no se pudo hacer.
    # Contarlo como veredicto acercaría el evolutivo a la escalada por una
    # avería de red, que es justo lo que protege el invariante 7.
    initiative = place(build_initiative, :tank)
    antes = initiative.qa_cycles_consumed

    Runtime.stub(:run, ->(_) { raise Runtime::Error, "el brain respondió 502" }) do
      assert_raises(Runtime::Error) do
        Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)
      end
    end

    run = initiative.agent_runs.last
    assert_equal "failed", run.status
    assert_match "502", run.error
    assert_equal antes, initiative.reload.qa_cycles_consumed
  end

  test "un fallo no publica artefacto a medias" do
    initiative = place(build_initiative, :tank)

    Runtime.stub(:run, ->(_) { raise Runtime::Unreachable, "el brain no responde" }) do
      assert_raises(Runtime::Error) do
        Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)
      end
    end

    assert_empty initiative.artifacts
  end

  test "un run fallido no bloquea el relanzamiento" do
    # Es la mitad que hace utilizable lo anterior: si el run fallido siguiera
    # contando como vivo, nadie podría reintentar sin tocar la base de datos.
    initiative = initiative_ready_for_tank

    Runtime.stub(:run, ->(_) { raise Runtime::Error, "502" }) do
      assert_raises(Runtime::Error) do
        Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)
      end
    end

    assert_nothing_raised do
      Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)
    end
  end

  test "el coste se guarda en centimos y redondea al alza" do
    # Un agregado de muchas ejecuciones baratas no puede acabar diciendo que no
    # costaron nada.
    initiative = place(build_initiative, :tank)
    barata = { "input_tokens" => 10, "output_tokens" => 20, "cost_usd" => 0.0034 }

    Runtime.stub(:run, ->(_) { result_with(barata) }) do
      outcome = Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)

      assert_equal 1, outcome.agent_run.cost_cents
    end
  end

  private
    # El fixture de TANK cita `booking-core` y `owner-web`, y el modelo rechaza
    # una cita de código cuyo repositorio no existe. Que haga falta montarlos es
    # el invariante trabajando: no hay afirmación sobre código sin repositorio.
    def initiative_ready_for_tank
      initiative = place(build_initiative, :tank)
      client = initiative.platform_client

      %w[booking-core owner-web pricing-svc].each do |name|
        InitiativeRepository.create!(
          initiative: initiative,
          repository: build_repository(client: client, name: name),
          pinned_sha: "4f2a9c1")
      end

      initiative
    end

    def result_with(usage)
      Runtime::Result.new(
        agent: "tank", purpose: "context", body: "## Qué se pide\n\nAlgo.",
        citations: [], events: [], findings: [], usage: usage,
        request_id: "req-1")
    end
end
