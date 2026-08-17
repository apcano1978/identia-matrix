# La guía de pruebas manuales: lo que la automatización no alcanzó.
#
# **Un documento, dos lecturas.** No hay dos guías ni dos modelos: hay un
# `test_guide` con sus pasos y un conmutador que decide qué se enseña y qué se
# esconde. El conmutador es Stimulus puro, sin ida al servidor, porque el
# contenido ya está en la página: cambiar de modo no es pedir nada nuevo.
class GuidesController < ApplicationController
  include InitiativeScoped

  def show
    @guide = current_guide
    return redirect_after(initiative_path_for, alert: no_guide) if @guide.blank?

    @steps = @guide.steps_in_order
                   .includes(:walked_by_user, :exempted_by_user,
                             :opened_escalations,
                             dod_criterion: :repository)
    @coverage = @guide.coverage
    @blocking = @guide.blocking_steps
    @report = @guide.verification_report
  end

  private
    def no_guide
      "#{@initiative.code} todavía no tiene guía de pruebas: la emite SERAPH al " \
        "dar conforme."
    end
end
