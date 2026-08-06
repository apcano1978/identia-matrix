# Los seis agentes, en SOLO LECTURA. Editar su configuración es F9, cuando haya
# agentes de verdad a los que configurar; la pantalla existe antes para que la
# entrada AGENTES del rail no lleve a un hueco durante seis fases.
class AgentsController < ApplicationController
  # En ORDEN DE PIPELINE, no en el del enum: es el orden en el que actúan, y
  # sale de `Pipeline::STAGE_WORK` para que añadir una etapa lo mantenga solo.
  AGENTS = Pipeline::STAGE_WORK.values.map { |work| work[:agent] }.uniq.freeze

  def index
    @agent = AGENTS.include?(params[:key]) ? params[:key] : AGENTS.first
    @client = Platform::Client.find_by(slug: params[:scope])

    @global = AgentConfig.global.find_by(agent: @agent)&.settings || {}
    @override = if @client
      AgentConfig.find_by(agent: @agent,
                          platform_client_id: @client.id)&.settings || {}
    else
      {}
    end
    @effective = AgentConfig.effective_for(agent: @agent, client: @client&.id)

    @clients = Platform::Client.active.order(:platform_id)
    @runs = AgentRun.where(agent: @agent).includes(:initiative)
                    .order(started_at: :desc).limit(8)
  end

  def show = redirect_to(agents_path(key: params[:key]))
end
