# El informe de verificación: el dictamen contra el contrato.
#
# SERAPH no valida: solo dictamina y emite la guía. La conformidad final la
# firma un humano en GATE 2, y esa separación es la que da sentido a las dos
# pantallas.
class VerificationsController < ApplicationController
  include InitiativeScoped

  def show
    @report = current_report
    return redirect_after(initiative_path_for, alert: no_report) if @report.blank?

    @dod = @report.definition_of_done
    @verdicts = @report.verdicts
                       .includes(:guide_step, :evidence_citation,
                                 dod_criterion: :repository)
                       .to_a.sort_by { |verdict| verdict.dod_criterion.key }
    @ci_checks = @report.ci_checks.includes(:repository)
                        .to_a.sort_by { |check| check.repository.name }
    @guide = current_guide
  end

  private
    def no_report
      "#{@initiative.code} todavía no tiene informe de verificación: lo emite " \
        "SERAPH tras la ejecución."
    end
end
