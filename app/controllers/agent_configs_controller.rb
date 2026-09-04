# Editar la configuración de un agente (P2).
#
# ── El único `update` del sistema, y por qué ───────────────────────────────
#
# Las otras doce escrituras de matrix son `create`: actos que ocurren una vez y
# dejan constancia. Esta no lo es, y forzarla a serlo habría sido ceremonia. Un
# ajuste de agente no es un hecho que ocurrió: es cómo se trabaja HOY, y su
# valor anterior no es historia que nadie vaya a citar.
#
# La pregunta que el invariante existe para provocar sí tiene respuesta, y no es
# esta tabla. Es: **si mañana cambio el umbral, ¿queda inexplicable el artefacto
# que MORFEO aprobó ayer?** Los artefactos son inmutables y no se pueden anotar
# después. La respuesta está en `agent_runs.config`, que guarda la configuración
# EFECTIVA con la que corrió cada ejecución: la vigente contesta «cómo se trabaja
# hoy» y aquella contesta «cómo se hizo esto», que es la que importa al auditar
# un evolutivo cerrado hace tres meses.
class AgentConfigsController < ApplicationController
  def update
    authorize AgentConfig, :update?

    # `agent_key` y no `agent`: la ruta cuelga de `resources :agents, param: :key`,
    # así que Rails prefija el parámetro del padre.
    agent = AgentsController::AGENTS.find { |key| key == params[:agent_key] }
    return redirect_back_or_to(agents_path, alert: "Agente desconocido.") if agent.blank?

    client = Platform::Client.find_by(slug: params[:scope])
    save(agent, client)

    redirect_to agents_path(key: agent, scope: client&.slug), status: :see_other,
                notice: notice_for(agent, client)
  end

  private
    def save(agent, client)
      config = AgentConfig.find_or_initialize_by(agent: agent,
                                                 platform_client_id: client&.id)
      config.settings = settings_for(agent, client)
      config.updated_by_user = Current.user
      config.save!
    end

    # Un override de cliente se poda: las claves bloqueadas no son suyas. La
    # global no, porque ahí es donde esos ajustes viven de verdad — bloquearlas
    # también dejaría el sistema sin forma de cambiarlas nunca.
    def settings_for(agent, client)
      parsed = JSON.parse(params.require(:settings))
      raise JSON::ParserError, "la configuración tiene que ser un objeto" unless parsed.is_a?(Hash)

      client ? AgentConfig.without_locked(parsed, agent: agent) : parsed
    end

    def notice_for(agent, client)
      scope = client ? "para #{client.slug}" : "global"
      locked = client ? AgentConfig.locked_for(agent) : []
      ignored = locked.any? ? " Los ajustes bloqueados no admiten override." : ""

      "Configuración de #{agent.upcase} #{scope} guardada.#{ignored}"
    end

    rescue_from JSON::ParserError do
      redirect_back_or_to(agents_path, status: :see_other,
                          alert: "La configuración no es un JSON válido; no se ha guardado nada.")
    end
end
