# La cuarta bifurcación: devolver a TRINITY con nota, desde GATE 1.
#
# No es una variante del rechazo de GATE 2. Devuelve a **TRINITY** y no a NEO
# porque lo que está mal es el paquete, no la especificación: reescribir la spec
# para arreglar un orden de despliegue sería rehacer lo que estaba bien.
#
# Exige una NOTA HUMANA, y no es formalidad: sin ella TRINITY volvería a sellar
# el mismo paquete sin saber qué corregir. Entra como nota de nivel ORIGEN.
class ReturnToTrinitiesController < ApplicationController
  include InitiativeScoped

  def create
    authorize @initiative, :send_back?, policy_class: GatePolicy

    note = params[:note].to_s.strip
    if note.blank?
      return redirect_after(gate_1_path,
                            alert: "Devolver a TRINITY exige decir qué corregir.")
    end

    human_note = write_note(note)
    Pipeline::SendBack.call(initiative: @initiative, to: :trinity,
                            actor: Current.user.to_s, human_note: human_note,
                            summary: note.truncate(80))

    redirect_after(initiative_path_for,
                   notice: "Devuelto a TRINITY. La iteración sube; el ciclo de QA no.")
  rescue Pipeline::Error => error
    redirect_after(gate_1_path, alert: error.message)
  end

  private
    def gate_1_path = client_initiative_gate_1_path(@client, @initiative)

    def write_note(body)
      HumanNote.create!(
        initiative: @initiative, platform_client: @client,
        author_user: Current.user,
        code: HumanNote.code_for(Current.user, client: @client),
        body: body)
    end
end
