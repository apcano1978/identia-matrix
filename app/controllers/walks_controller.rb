# Marcar un paso de la guía como recorrido.
#
# `create` y no `update`: recorrer un paso es un acto que ocurre una vez y deja
# constancia de quién y cuándo, no la edición de un campo.
class WalksController < ApplicationController
  include InitiativeScoped

  def create
    step = load_step
    authorize step, :walk?

    Guides::WalkStep.call(step: step, user: Current.user,
                          note: params[:walk_note].presence)

    redirect_after(client_initiative_guide_path(@client, @initiative,
                                                anchor: "paso-#{format('%02d', step.position)}"))
  end

  private
    def load_step
      GuideStep.joins(:test_guide)
               .where(test_guides: { initiative_id: @initiative.id })
               .find(params[:guide_step_id])
    end
end
