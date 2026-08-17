# Validar o rechazar en GATE 2.
#
# Una sola acción para las dos decisiones, porque son la misma pregunta con dos
# respuestas: ¿lo ejecutado sirve? Separarlas en dos rutas sugeriría que
# rechazar es una excepción, y no lo es — GATE 2 es reversible por diseño.
class ValidationsController < ApplicationController
  include InitiativeScoped

  def create
    authorize @initiative, :validate?, policy_class: GatePolicy

    guide = current_guide
    return redirect_after(initiative_path_for, alert: "No hay guía que validar.") if guide.blank?

    result = Gates::Validate.call(
      initiative: @initiative, guide: guide, user: Current.user,
      decision: params[:decision], rejection_note: params[:rejection_note])

    redirect_after(initiative_path_for, notice: notice_for(result))
  rescue Gates::Validate::Blocked, ArgumentError => error
    redirect_after(client_initiative_gate_2_path(@client, @initiative),
                   alert: error.message)
  end

  private
    def notice_for(result)
      return "GATE 2 validado. LINK redacta el cierre." if result.validation.decision_validated?

      "Rechazado y devuelto a NEO. La iteración sube; el ciclo de QA no."
    end
end
