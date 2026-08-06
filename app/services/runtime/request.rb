# La petición que viaja a brain, construida desde un `AgentRun` y validada
# contra `agent_run.v1.json`.
#
# Se valida también con el runtime falso. No es ceremonia: es la única forma de
# saber que lo que matrix construye cabe en el contrato antes de que exista el
# otro extremo, y el contrato es lo que se congela en F9.
#
# **Contexto mínimo a propósito.** Aquí van cliente, evolutivo, etapa, ciclo y
# repositorios. Las fuentes, los artefactos previos y las notas humanas —la
# memoria acumulada, que es lo caro de ensamblar— son trabajo de F9.
module Runtime::Request
  CONTRACT_VERSION = 1
  DEFAULT_MODEL = "chat-default".freeze

  # El agente y el propósito NO van en el cuerpo: el endpoint es
  # `POST /v1/agents/{key}/run`, así que la clave viaja en la URL. Van fuera del
  # payload y no dentro para que lo que se valida contra el contrato sea
  # exactamente lo que se enviará.
  Envelope = Data.define(:agent, :purpose, :payload)

  module_function

  def for(agent_run)
    initiative = agent_run.initiative

    payload = {
      "contract_version" => CONTRACT_VERSION,
      "config" => config_for(agent_run),
      "context" => {
        "client" => client_of(initiative),
        "initiative" => initiative_of(initiative),
        "repositories" => repositories_of(initiative),
        "stage" => initiative.current_stage,
        "qa_cycle" => initiative.qa_cycles_consumed
      }
    }

    Contracts.validate!(:matrix_brain_agent_run, payload)

    Envelope.new(agent: agent_run.agent, purpose: agent_run.purpose,
                 payload: payload)
  end

  def config_for(agent_run)
    settings = AgentConfig.effective_for(
      agent: agent_run.agent,
      client: agent_run.initiative.platform_client_id)

    { "model" => DEFAULT_MODEL }.merge(settings.stringify_keys)
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
end
