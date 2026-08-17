# Firmar GATE 1.
#
# `create` y nada más: una firma no se edita ni se borra. Que no exista otra
# ruta se lee en `bin/rails routes`, sin abrir este fichero.
class SignaturesController < ApplicationController
  include InitiativeScoped

  def create
    authorize @initiative, :sign?, policy_class: GatePolicy

    Gates::Sign.call(initiative: @initiative, user: Current.user,
                     password: params[:password])

    redirect_after(client_initiative_gate_1_path(@client, @initiative),
                   notice: "GATE 1 firmado. La ejecución queda autorizada.")
  rescue Gates::Sign::Refused => error
    redirect_after(client_initiative_gate_1_path(@client, @initiative),
                   alert: "No se ha firmado: #{error.message}.")
  end
end
