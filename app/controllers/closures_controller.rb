# Cerrar el acta y salir de la etapa 1.
#
# `create` y no `update`: cerrar el acta es un acto irreversible que publica un
# artefacto inmutable y mueve el evolutivo. No se deshace — lo que venga después
# es otro delta, que es la regla entera de la que cuelga la inmutabilidad de las
# decisiones.
#
# Se puede cerrar con decisiones abiertas, y el porqué está en `Actas::Close`.
class ClosuresController < ApplicationController
  include InitiativeScoped

  def create
    authorize @initiative, :run_agent?

    result = Actas::Close.call(initiative: @initiative,
                               actor: Current.user.email_address)

    redirect_after(initiative_path_for, notice: closed_notice(result))
  rescue Actas::Close::Refused => error
    redirect_after(project_initiative_acta_path(@project, @initiative),
                   alert: "No se ha cerrado: #{error.message}.")
  end

  private
    # Al cerrar se sale de la pantalla del acta y se vuelve al evolutivo: lo que
    # había que decidir está decidido, y lo siguiente pasa en el pipeline.
    def closed_notice(result)
      base = "Acta #{result.artifact.code} cerrada. #{@initiative.title} entra en TANK"

      return "#{base}." if result.open_count.zero?

      "#{base} con #{pluralize_open(result.open_count)} sin contestar: no " \
        "bloquean, pero MORFEO las levantará y LINK las recuperará al cerrar."
    end

    def pluralize_open(count)
      count == 1 ? "1 decisión" : "#{count} decisiones"
    end
end
