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
    initiative = initiative_at_tank
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

  # ── F12 · B6 · nadie trabaja sin haber leído el código ───────────────────

  # ⚠ LA MITAD DE P23 QUE ENCOLAR NO CIERRA. Indexar solo arregla el olvido; un
  # `remote_url` ilegible sigue dejando el evolutivo sin anclar, y entonces TANK
  # escribiría su dossier sin haber visto una línea de código. No falla: acierta
  # plausible, que es peor.
  test "sin ningun repositorio anclado, el agente se niega" do
    initiative = place(build_initiative, :tank)

    error = assert_raises(Agents::Run::Refused) do
      Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)
    end

    assert_match "TANK", error.message
    assert_match "ningún repositorio anclado", error.message
  end

  test "y no deja fila de ejecucion de algo que no va a ocurrir" do
    initiative = place(build_initiative, :tank)

    assert_no_difference -> { AgentRun.count } do
      assert_raises(Agents::Run::Refused) do
        Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)
      end
    end
  end

  # La excepción, y no es un permiso: es el orden del runbook. El acta va ANTES
  # de indexar —camino C, paso 5 frente al 7— porque el ARQUITECTO entrevista a
  # una persona. Es justo el momento en que no hay nada anclado todavía.
  test "pero el ARQUITECTO trabaja igual: para eso va antes de indexar" do
    initiative = place(build_initiative, :need)

    assert_nothing_raised do
      Agents::Run.call(initiative: initiative, agent: :arquitecto, purpose: :interview)
    end
  end

  # Con uno anclado basta: un evolutivo multi-repo del que solo uno se pudo leer
  # tiene material, y pararlo entero sería peor que trabajar con lo que hay.
  test "y con un solo repositorio anclado ya se puede trabajar" do
    assert_nothing_raised do
      Agents::Run.call(initiative: initiative_at_tank, agent: :tank, purpose: :context)
    end
  end

  # El motivo, con el del repositorio al lado: «sin origen legible» y «el origen
  # no respondió» piden cosas distintas de quien lo lee.
  test "el motivo nombra el repositorio y lo que le pasa" do
    initiative = place(build_initiative, :tank)
    repository = build_repository(client: initiative.platform_client, name: "booking-core")
    InitiativeRepository.create!(initiative: initiative, repository: repository,
                                 indexing_error: "sin origen legible")

    assert_match "booking-core · sin origen legible",
                 Agents::Run.blind_reason(initiative)
  end

  # ── Criterio 8 · un fallo técnico no es un veredicto ─────────────────────

  test "un fallo del brain deja el run en failed y NO consume ciclo de QA" do
    # Que el brain responda 502 no es un ✕: es que la llamada no se pudo hacer.
    # Contarlo como veredicto acercaría el evolutivo a la escalada por una
    # avería de red, que es justo lo que protege el invariante 7.
    initiative = initiative_at_tank
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
    initiative = initiative_at_tank

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
    initiative = initiative_at_tank
    barata = { "input_tokens" => 10, "output_tokens" => 20, "cost_usd" => 0.0034 }

    Runtime.stub(:run, ->(_) { result_with(barata) }) do
      outcome = Agents::Run.call(initiative: initiative, agent: :tank, purpose: :context)

      assert_equal 1, outcome.agent_run.cost_cents
    end
  end

  private
    # ⚠ UN EVOLUTIVO EN TANK TIENE CÓDIGO ANCLADO, y desde F12 · B6 eso no es un
    # detalle del montaje: es la condición para que TANK pueda trabajar. Sin
    # `pinned_sha`, `Runtime::Request` mandaría `"repositories" => []` y el
    # agente escribiría sin haber visto una línea de código — `Agents::Run` se
    # niega, que es lo que este helper deja de tener que discutir en cada test.
    def initiative_at_tank
      initiative = place(build_initiative, :tank)
      InitiativeRepository.create!(
        initiative: initiative,
        repository: build_repository(client: initiative.platform_client,
                                     name: "booking-core"),
        pinned_sha: "4f2a9c1")

      initiative
    end

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
