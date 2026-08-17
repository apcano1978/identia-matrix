# Autorizar que un paso se cierre sin la prueba que nadie pudo hacer.
#
# La policy comprueba las dos condiciones: tener autoridad, y **no ser quien
# levantó la mano**. Nadie autoriza su propia solicitud — es la regla que de
# verdad protege, y no depende de ningún papel.
class ExemptionsController < ApplicationController
  include InitiativeScoped

  def create
    step = load_step
    authorize step, :authorize_exemption?

    Guides::AuthorizeExemption.call(step: step, user: Current.user,
                                    reason: params[:reason].to_s.strip)

    redirect_after(gate_2_path(step),
                   notice: "Paso eximido. Queda escrito quién lo autorizó y por qué.")
  rescue Guides::AuthorizeExemption::Refused => error
    redirect_after(gate_2_path(step), alert: error.message)
  end

  private
    def load_step
      GuideStep.joins(:test_guide)
               .where(test_guides: { initiative_id: @initiative.id })
               .find(params[:guide_step_id])
    end

    def gate_2_path(step)
      client_initiative_gate_2_path(@client, @initiative,
                                    anchor: "paso-#{format('%02d', step.position)}")
    end
end
