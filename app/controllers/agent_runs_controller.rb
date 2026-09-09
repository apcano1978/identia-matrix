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

    # ⚠ ANTES DE ENCOLAR (F12 · B6). `Agents::Run` se niega igual —es la guarda
    # de verdad, y vale también para el recorrido de consola— pero eso ocurre
    # dentro del job: sin esta comprobación, quien pulsa leería «TANK está
    # trabajando» y el trabajo moriría en silencio treinta segundos después.
    if Agents::Run.blind?(initiative: @initiative, agent: work[:agent])
      return redirect_with(alert: blind_message(work))
    end

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

    # Sin código anclado, un agente escribiría sin haber visto una línea de él.
    # No falla: acierta plausible, que es peor — es lo que P23 describía.
    def blind_message(work)
      "#{work[:agent].upcase} no puede trabajar todavía: " \
        "#{Agents::Run.blind_reason(@initiative)}. Se indexa solo al abrir el " \
        "evolutivo; si sigue así, mira el motivo en fuentes o reindexa con " \
        "matrix:index."
    end

    def redirect_with(**flash)
      redirect_to project_initiative_path(@project, @initiative),
                  status: :see_other, **flash
    end
end
