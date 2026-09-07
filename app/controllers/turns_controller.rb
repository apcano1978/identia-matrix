# Contestar al ARQUITECTO.
#
# **La única acción de matrix que corre dentro de la petición.** El resto de
# agentes son un job de Sidekiq: se lanzan, tardan y publican. Aquí hay una
# persona esperando la respuesta, y meter una cola entre su pregunta y lo que el
# agente contesta convertiría la entrevista en un formulario.
#
# `create` y no `update`: cada turno es un acto que ocurre una vez y deja
# constancia —una nota citable y una fila en `agent_runs` con su coste—. Que el
# turno además ACTUALICE filas de `decisions` está sopesado en la lista blanca:
# esa mutabilidad está acotada por la publicación del acta, no abierta.
class TurnsController < ApplicationController
  include InitiativeScoped

  def create
    authorize @initiative, :run_agent?

    Actas::Turn.call(initiative: @initiative, message: params[:message],
                     author: Current.user)

    redirect_after(acta_path, notice: "Turno registrado. El acta recoge lo que " \
                                      "el ARQUITECTO ha podido cerrar.")
  rescue Actas::Turn::Refused, Decisions::Apply::Refused => error
    redirect_after(acta_path, alert: "No se ha podido registrar: #{error.message}.")
  rescue Runtime::Error => error
    # «El brain no contesta» no es lo mismo que «el turno no valía», y quien
    # espera delante de la pantalla necesita saber cuál de las dos fue: lo
    # primero se reintenta, lo segundo se corrige.
    redirect_after(acta_path,
                   alert: "El ARQUITECTO no ha contestado: #{error.message}. " \
                          "Tu nota queda registrada; vuelve a intentarlo.")
  end

  private
    def acta_path = project_initiative_acta_path(@project, @initiative)
end
