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
                 payload.dig("config", "client", "slug")
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

    repositories = Runtime::Request.for(run).payload.dig("config", "repositories")

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

  # ── El material, y quién lo recibe ───────────────────────────────────────

  test "el contexto del evolutivo va en `config`, no en `context`" do
    # `AgentContext` del brain tiene cuatro campos y no declara extra=forbid:
    # todo lo que viajara en `context` se habría descartado en silencio.
    payload = Runtime::Request.for(agent_run).payload

    assert_equal %w[source], payload["context"].keys
    assert payload["config"].key?("client")
    assert payload["config"].key?("initiative")
  end

  test "TANK recibe las fuentes en ámbito, con su cuerpo" do
    run = agent_run
    client = run.initiative.platform_client
    document = build_document(client: client, slug: "acta-precios", body: "Lo acordado.")
    InitiativeSource.create!(initiative: run.initiative, source: document)

    sources = Runtime::Request.for(run).payload.dig("config", "sources")

    assert_equal [ "acta-precios" ], sources.map { |s| s["slug"] }
    assert_equal "Lo acordado.", sources.first["body"]
  end

  test "una fuente sin cuerpo no viaja" do
    # No se puede citar por ancla, y mandarla invitaría al agente a citar algo
    # que después no resuelve.
    run = agent_run
    client = run.initiative.platform_client
    InitiativeSource.create!(initiative: run.initiative,
                             source: build_document(client: client, body: nil))

    assert_empty Runtime::Request.for(run).payload.dig("config", "sources").to_a
  end

  test "TANK recibe las notas humanas del evolutivo" do
    run = agent_run
    client = run.initiative.platform_client
    author = build_platform_user(name: "Antonio Pérez")
    HumanNote.create!(initiative: run.initiative, platform_client: client,
                      author_user: author, body: "Se reinicia tras la escalada.",
                      code: HumanNote.code_for(author, client: client))

    notes = Runtime::Request.for(run).payload.dig("config", "human_notes")

    assert_equal 1, notes.size
    assert_equal "Antonio Pérez", notes.first["author"]
    assert_empty Contracts.errors(:matrix_brain_agent_run, Runtime::Request.for(run).payload)
  end

  # ── §3 · La independencia de LINK se impone en el código ─────────────────

  test "NEO y LINK no comparten material de trabajo" do
    # «Quien escribió el plan es el peor narrador del desvío frente al plan.»
    # Dejarlo en el prompt sería confiar en que un modelo se autolimite; aquí
    # son entradas disjuntas repartidas por la tabla MATERIAL, y este test es el
    # que se pone rojo si alguien «optimiza» dándole a LINK lo de NEO.
    initiative = place(build_initiative, :tank)
    client = initiative.platform_client
    InitiativeSource.create!(
      initiative: initiative,
      source: build_document(client: client, slug: "acta", body: "Lo acordado."))

    neo = config_for(initiative, agent: :neo, purpose: :spec)
    link = config_for(initiative, agent: :link, purpose: :closure)

    assert neo.key?("sources"), "NEO sí redacta el plan y necesita las fuentes"
    refute link.key?("sources"),
           "LINK no recibe las fuentes: no reescribe el plan, cuenta qué pasó con él"
  end

  test "de las notas, LINK solo recibe las de reinicio" do
    # Las demás son material de redacción. Una nota de reinicio explica un
    # desvío, que es exactamente lo que LINK narra.
    initiative = place(build_initiative, :tank)
    client = initiative.platform_client
    author = build_platform_user(name: "Antonio Pérez")

    corriente = note_for(initiative, author, "Una aclaración de trabajo")
    reinicio = note_for(initiative, author, "Se reinicia tras la escalada")
    Escalation.create!(initiative: initiative, platform_client: client,
                       reason: "qa_cycles_exhausted", human_note: reinicio,
                       opened_at: Time.current)

    neo = config_for(initiative, agent: :neo, purpose: :spec)
    link = config_for(initiative, agent: :link, purpose: :closure)

    assert_equal [ corriente.code, reinicio.code ].sort,
                 neo["human_notes"].map { |n| n["code"] }.sort
    assert_equal [ reinicio.code ], link["human_notes"].map { |n| n["code"] }
  end

  test "SERAPH y TRINITY no reciben las fuentes" do
    initiative = place(build_initiative, :tank)

    refute config_for(initiative, agent: :seraph, purpose: :dod_pass).key?("sources")
    refute config_for(initiative, agent: :trinity, purpose: :package).key?("sources")
  end

  # ── El modelo, por papel ─────────────────────────────────────────────────

  test "MORFEO y SERAPH van a un modelo con mas razonamiento" do
    # MORFEO revisa de forma adversarial y SERAPH dictamina: equivocarse ahí
    # sale caro en las dos direcciones.
    initiative = place(build_initiative, :tank)

    assert_equal "chat-deep", config_for(initiative, agent: :morfeo, purpose: :review)["model"]
    assert_equal "chat-deep", config_for(initiative, agent: :seraph, purpose: :dod_pass)["model"]
    assert_equal "chat-default", config_for(initiative, agent: :tank, purpose: :context)["model"]
  end

  test "la configuracion del agente puede fijar el alias, y `engine` no lo hace" do
    # `engine` es el id de modelo que trae la maqueta (`claude-sonnet-4-6`), no
    # un alias de models.yaml. El brain enruta por alias, así que un id crudo
    # dejaría a su router sin saber a quién preguntar.
    initiative = place(build_initiative, :tank)
    AgentConfig.create!(agent: :tank, settings: { "model" => { "engine" => "claude-sonnet-4-6" } })

    assert_equal "chat-default", config_for(initiative, agent: :tank, purpose: :context)["model"]

    AgentConfig.find_by(agent: :tank, platform_client_id: nil)
               .update!(settings: { "model" => { "alias" => "chat-fast" } })

    assert_equal "chat-fast", config_for(initiative, agent: :tank, purpose: :context)["model"]
  end

  private
    # `status: :ok` y no `:running`: el índice único parcial no deja dos filas
    # VIVAS del mismo (evolutivo, agente, propósito, iteración), y este ayudante
    # construye varias del mismo agente para comparar. Que estorbe aquí es la
    # prueba de que el candado está puesto donde tiene que estar.
    def config_for(initiative, agent:, purpose:)
      run = AgentRun.create!(
        initiative: initiative, agent: agent, purpose: purpose,
        code: "run-#{SecureRandom.hex(4)}", status: :ok)

      Runtime::Request.for(run).payload["config"]
    end

    def note_for(initiative, author, body)
      client = initiative.platform_client
      HumanNote.create!(initiative: initiative, platform_client: client,
                        author_user: author, body: body,
                        code: HumanNote.code_for(author, client: client))
    end

    def agent_run
      @agent_run ||= AgentRun.create!(
        initiative: place(build_initiative, :tank), agent: :tank,
        purpose: :context, code: "run-#{SecureRandom.hex(4)}", status: :running)
    end
end
