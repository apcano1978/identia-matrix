# GATE 2 · confirmas que lo ejecutado sirve.
#
# No autorizas nada: eso fue GATE 1. Y a diferencia de aquélla, ésta **es
# reversible por rechazo**.
class Gate2Controller < ApplicationController
  include InitiativeScoped

  def show
    @guide = current_guide
    return redirect_after(initiative_path_for, alert: no_guide) if @guide.blank?

    @steps = @guide.steps_in_order
                   .includes(:walked_by_user, :exempted_by_user,
                             opened_escalations: :opened_by_user,
                             dod_criterion: :repository)
    @coverage = @guide.coverage
    @blocking = @guide.blocking_steps
    @sole_evidence = @steps.select(&:evidence_sole_evidence?)
    @may_validate = GatePolicy.new(Current.user, @initiative).validate?
    @decisions = @initiative.gate_validations.chronological.includes(:decided_by_user)
  end

  private
    def no_guide
      "#{@initiative.code} todavía no tiene guía de pruebas: sin ella no hay " \
        "nada que validar."
    end
end
