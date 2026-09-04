# La petición que viaja a brain, construida desde un `AgentRun` y validada
# contra `agent_run.v1.json`.
#
# Se valida también con el runtime falso. No es ceremonia: es la única forma de
# saber que lo que matrix construye cabe en el contrato antes de que exista el
# otro extremo.
#
# ── Dónde va el contexto del evolutivo ─────────────────────────────────────
#
# En `config`, no en `context`, enmendando lo que F0 dejó escrito. `AgentContext`
# del brain es una clase COMPARTIDA con Pepper, Natasha, Clark y Vision, tiene
# cuatro campos —request_id, dedupe_seen_urls, agent_token, source— y no declara
# `extra="forbid"`: descarta en silencio lo que no reconoce. Todo lo que matrix
# mandara en `context` se habría tirado sin que nadie se enterase.
#
# La regla que se deduce del propio brain, donde Pepper ya recibe `lead_context`
# y `transcriptions` en `config`: **`config` son las entradas del trabajo,
# `context` es infraestructura de ejecución**.
#
# ── Un constructor por agente ──────────────────────────────────────────────
#
# Cada agente recibe SOLO lo suyo, y no por economía: es así como se impone que
# LINK no comparta contexto de redacción con NEO. Quien escribió el plan es el
# peor narrador del desvío frente al plan, y dejar eso en el prompt sería
# confiar en que un modelo se autolimite. Aquí las entradas son disjuntas
# porque el código las reparte.
module Runtime::Request
  CONTRACT_VERSION = 1
  DEFAULT_MODEL = "chat-default".freeze

  # Qué material recibe cada agente. La tabla ES la regla: si mañana alguien
  # quiere que LINK lea el dossier, tiene que venir aquí y decirlo, y entonces
  # el test que comprueba que NEO y LINK son disjuntos se pondrá rojo.
  #
  #   sources         los documentos y actas en ámbito
  #   prior_artifacts la memoria acumulada de los evolutivos ANTERIORES
  #   finished        los artefactos TERMINADOS de este evolutivo
  #   human_notes     todo lo que una persona escribió, nivel ORIGEN
  #   restart_notes   solo las notas que resolvieron una escalada
  MATERIAL = {
    "tank"    => %i[sources prior_artifacts human_notes],
    "neo"     => %i[sources prior_artifacts human_notes],
    "seraph"  => %i[finished],
    "morfeo"  => %i[sources finished],
    "trinity" => %i[finished],
    # LINK lee la spec como documento CERRADO, no como material de trabajo: no
    # está reescribiendo el plan, está contando qué pasó con él. Por eso no
    # recibe ni las fuentes ni la memoria del repositorio, y de las notas solo
    # las de REINICIO — las que explican un desvío, que es lo que narra.
    "link"    => %i[finished restart_notes]
  }.freeze

  # Los artefactos que cuentan como «terminados» de este evolutivo.
  FINISHED_KINDS = %w[spec dod verify pkg].freeze

  # El agente y el propósito NO van en el cuerpo: el endpoint es
  # `POST /v1/agents/{key}/run`, así que la clave viaja en la URL. Van fuera del
  # payload y no dentro para que lo que se valida contra el contrato sea
  # exactamente lo que se enviará.
  Envelope = Data.define(:agent, :purpose, :payload)

  module_function

  def for(agent_run)
    payload = {
      "contract_version" => CONTRACT_VERSION,
      "config" => config_for(agent_run),
      "context" => { "source" => "initiative:#{agent_run.initiative.code}" }
    }

    Contracts.validate!(:matrix_brain_agent_run, payload)

    Envelope.new(agent: agent_run.agent, purpose: agent_run.purpose,
                 payload: payload)
  end

  # `config` lleva dos cosas que no se pueden mezclar: los parámetros de llamada
  # que entiende brain y el material del evolutivo.
  #
  # Los ajustes de `agent_configs` van APARTE, bajo `matrix`, y eso no es orden
  # sino una bomba de relojería desactivada: en cuanto una sección se llamó
  # `model`, pisó el alias del contrato con un hash y la petición dejó de validar.
  def config_for(agent_run)
    initiative = agent_run.initiative
    settings = AgentConfig.effective_for(
      agent: agent_run.agent, client: initiative.platform_client_id)

    {
      "model" => model_for(agent_run.agent, settings),
      "matrix" => settings.deep_stringify_keys,
      "client" => client_of(initiative),
      "initiative" => initiative_of(initiative),
      "stage" => initiative.current_stage,
      "qa_cycle" => initiative.qa_cycles_consumed,
      "repositories" => repositories_of(initiative)
    }.merge(material_for(agent_run))
  end

  # El alias de modelo con el que corre cada agente.
  #
  # Diferenciado por PAPEL, no uniforme: MORFEO revisa de forma adversarial y
  # SERAPH dictamina, y equivocarse ahí sale caro en las dos direcciones —un
  # MORFEO flojo aprueba lo que no debía, y un TRINITY caro solo estructura—.
  # La maqueta pone el mismo modelo en sus tres paneles; esto es una divergencia
  # deliberada.
  MODEL_BY_AGENT = {
    "morfeo" => "chat-deep",
    "seraph" => "chat-deep"
  }.freeze

  # De la configuración del agente si la declara, y si no del papel.
  #
  # ⚠ La clave es `alias` y NO `engine`, que es la que trae la maqueta. `engine`
  # dice `claude-sonnet-4-6`: un id de modelo, no un alias de `models.yaml`. El
  # brain enruta por alias —`chat-default`, `chat-deep`, `chat-fast`— y con un id
  # crudo su router no sabría a quién preguntar. Son dos vocabularios distintos y
  # confundirlos habría fallado en la primera llamada real.
  #
  # Y las claves de `settings` son cadenas, no símbolos: vienen de un `jsonb`.
  def model_for(agent, settings)
    settings.dig("model", "alias").presence ||
      MODEL_BY_AGENT.fetch(agent.to_s, DEFAULT_MODEL)
  end

  # Solo lo que la tabla MATERIAL le concede a este agente. Lo que no aparece no
  # es un hueco: es la frontera.
  def material_for(agent_run)
    initiative = agent_run.initiative
    allowed = MATERIAL.fetch(agent_run.agent, [])

    material = {}
    material["sources"] = sources_of(initiative) if allowed.include?(:sources)

    if allowed.include?(:human_notes)
      material["human_notes"] = notes_of(initiative)
    elsif allowed.include?(:restart_notes)
      material["human_notes"] = notes_of(initiative, restarts_only: true)
    end

    previous = allowed.include?(:prior_artifacts) ? prior_artifacts_of(initiative) : []
    finished = allowed.include?(:finished) ? finished_artifacts_of(initiative) : []
    material["prior_artifacts"] = previous + finished if previous.any? || finished.any?

    material
  end

  def client_of(initiative)
    client = initiative.platform_client

    { "slug" => client.slug, "platform_id" => client.platform_id,
      "name" => client.name }
  end

  def initiative_of(initiative)
    {
      "code" => initiative.code, "title" => initiative.title,
      "platform_project_ref" => initiative.platform_project&.platform_project_ref
    }
  end

  # Solo los que tienen `pinned_sha`: el contrato lo exige, y un repositorio sin
  # anclar es uno del que TANK todavía no leyó nada. Mandarlo sin sha sería
  # decirle al agente que puede citar código que nadie ha fijado.
  def repositories_of(initiative)
    initiative.initiative_repositories.includes(:repository).filter_map do |link|
      next if link.pinned_sha.blank?

      { "name" => link.repository.name, "pinned_sha" => link.pinned_sha,
        "default_branch" => link.repository.default_branch,
        "indexed_files_count" => link.indexed_files_count }.compact
    end
  end

  # Las fuentes en ámbito, cuerpo incluido. Solo las CITABLES: una fuente sin
  # texto no se puede citar por ancla, y mandarla invitaría al agente a citar
  # algo que después no resuelve.
  def sources_of(initiative)
    Sources::Scope.scoped(initiative).flat_map do |kind, group|
      group.sources.select(&:citable?).map { |source| source_payload(kind, source) }
    end
  end

  def source_payload(kind, source)
    payload = {
      "kind" => kind == :documents ? "document" : "meeting",
      "platform_id" => source.platform_id,
      "title" => source.title,
      "slug" => source.slug,
      "body" => source.body
    }
    payload["occurred_on"] = source.held_on.iso8601 if source.respond_to?(:held_on) && source.held_on
    payload
  end

  # La memoria acumulada: lo que decidieron los evolutivos ANTERIORES sobre los
  # mismos repositorios. Es lo que permite que el tercero arranque sabiendo lo
  # que los dos primeros ya resolvieron, y la razón de que matrix exista.
  def prior_artifacts_of(initiative)
    Artifact.where(platform_client_id: initiative.platform_client_id)
            .where.not(initiative_id: initiative.id)
            .where(initiative_id: sibling_initiative_ids(initiative))
            .latest_first
            .limit(20)
            .map { |artifact| artifact_payload(artifact) }
  end

  # Los evolutivos que comparten repositorio con este. La memoria es del
  # REPOSITORIO, que es el eje que acumula: el otro eje, el evolutivo, muere al
  # publicarse.
  def sibling_initiative_ids(initiative)
    repository_ids = initiative.initiative_repositories.select(:repository_id)

    InitiativeRepository.where(repository_id: repository_ids)
                        .where.not(initiative_id: initiative.id)
                        .select(:initiative_id)
  end

  # Los artefactos ya terminados de ESTE evolutivo. Es lo que LINK narra y lo
  # que SERAPH y TRINITY toman como dado.
  def finished_artifacts_of(initiative)
    initiative.artifacts.where(kind: FINISHED_KINDS)
              .latest_first
              .map { |artifact| artifact_payload(artifact) }
  end

  def artifact_payload(artifact)
    {
      "key" => artifact.storage_key, "kind" => artifact.kind,
      "code" => artifact.code, "version" => artifact.version,
      "initiative_code" => artifact.initiative.code,
      # `body_markdown` y no los bytes crudos: el front-matter es metadato de
      # matrix —clave, checksum, versión—, no contenido. Mandárselo al agente
      # sería invitarle a citar una cabecera.
      "body" => artifact.body_markdown.to_s
    }
  end

  # Las notas humanas del evolutivo. Nivel ORIGEN: una nota de reinicio tras
  # escalada entra al corpus con el mismo peso que un acta.
  #
  # `restarts_only` es lo que separa a LINK de NEO. Una nota de reinicio es la
  # que resolvió una escalada, y es la que explica un desvío frente al plan;
  # las demás son material de redacción, y LINK no redacta el plan.
  def notes_of(initiative, restarts_only: false)
    scope = initiative.human_notes.chronological.includes(:author_user)
    scope = scope.where(id: Escalation.where.not(human_note_id: nil).select(:human_note_id)) if restarts_only

    scope.map do |note|
      { "code" => note.code, "body" => note.body,
        "author" => note.author_user.name }.compact
    end
  end
end
