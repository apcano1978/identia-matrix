# Poner a trabajar al agente que toca en la etapa actual.
#
# `create` y no `update`: lanzar es un acto que ocurre una vez y deja constancia
# —una fila en `agent_runs` con su consumo y su resultado—, no la edición de un
# campo.
#
# **Quién trabaja no lo elige quien pulsa.** Sale de `Pipeline::STAGE_WORK`, que
# es el mismo sitio del que lo saca el recorrido de consola. Dejarlo elegir
# permitiría pedirle a LINK que narre un cierre que todavía no ha ocurrido, y
# nada en el dominio lo impediría: el orden del pipeline es la única razón por
# la que un agente tiene material del que hablar.
class AgentRunsController < ApplicationController
  include InitiativeScoped

  def create
    authorize @initiative, :run_agent?

    work = Pipeline::STAGE_WORK[@initiative.current_stage]
    return redirect_with(alert: no_work_message) if work.blank?

    Agents::RunJob.perform_later(@initiative.id, **work.symbolize_keys)

    redirect_with(notice: "#{work[:agent].upcase} está trabajando en " \
                          "#{@initiative.code}. El resultado aparece aquí al terminar.")
  end

  private
    # Las etapas que no tienen agente son las que espera una PERSONA: las dos
    # puertas, la ejecución de Claude Code y la publicación. Que no haya botón
    # ahí no es un hueco.
    def no_work_message
      "En #{@initiative.current_stage.humanize} no trabaja ningún agente: " \
        "esta etapa la mueve una persona."
    end

    def redirect_with(**flash)
      redirect_to client_initiative_path(@client, @initiative),
                  status: :see_other, **flash
    end
end
