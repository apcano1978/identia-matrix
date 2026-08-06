class SessionsController < ApplicationController
  # Sin rail ni barra de título: todavía no hay sesión que resumir.
  layout "bare"

  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_url, alert: "Inténtalo de nuevo más tarde." }

  def new
  end

  def create
    outcome = Auth.authenticate(
      email_address: params[:email_address], password: params[:password])

    if outcome.ok?
      start_new_session_for outcome.user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: alert_for(outcome)
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end

  private
    # Se distingue «no puedes entrar» de «la credencial no vale» porque son
    # problemas distintos: uno lo arregla la persona y el otro un administrador
    # de platform. Ninguno de los dos revela si la cuenta existe.
    def alert_for(outcome)
      case outcome.error
      when Auth::NO_ACCESS
        "Tu cuenta de platform no tiene acceso a matrix."
      else
        "Correo o contraseña incorrectos."
      end
    end
end
