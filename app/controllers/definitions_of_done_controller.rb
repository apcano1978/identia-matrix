# El DoD: el contrato contra el que se verifica.
#
# Solo lectura. Lo escribe SERAPH y lo revisa MORFEO; aquí solo se lee, que es
# lo que hace posible discutirlo antes de que nadie firme nada.
class DefinitionsOfDoneController < ApplicationController
  include InitiativeScoped

  def show
    @dod = current_dod
    return redirect_after(initiative_path_for, alert: no_dod) if @dod.blank?

    @criteria = @dod.dod_criteria.includes(:repository, :verdicts,
                                           trace_citation: %i[repository target])
                    .order(:key)
    @report = current_report
    @verdicts = verdicts_by_criterion
  end

  private
    def no_dod
      "#{@initiative.code} todavía no tiene definición de terminado: la escribe " \
        "SERAPH tras la especificación."
    end

    # El veredicto vigente de cada criterio, del informe más reciente. Un
    # criterio puede tener varios a lo largo de los ciclos de QA y lo que la
    # tabla enseña es el último.
    def verdicts_by_criterion
      return {} if @report.blank?

      @report.verdicts.includes(:guide_step, :evidence_citation)
             .index_by(&:dod_criterion_id)
    end
end
