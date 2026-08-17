# «No puedo recorrer este paso.»
#
# No cierra nada: abre una escalada con el motivo y deja la decisión en manos de
# otra persona. Un bloqueo perpetuo empujaría a marcar el paso como recorrido
# sin haberlo hecho, que es el único desenlace peor que no cerrarlo.
class RaisedHandsController < ApplicationController
  include InitiativeScoped

  def create
    step = load_step
    authorize step, :raise_hand?

    Guides::RaiseHand.call(step: step, user: Current.user,
                           reason: params[:reason].to_s.strip)

    redirect_after(gate_2_path(step),
                   notice: "Mano levantada. Espera a que alguien lo autorice o " \
                           "lo recorra.")
  rescue Guides::RaiseHand::Refused => error
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
