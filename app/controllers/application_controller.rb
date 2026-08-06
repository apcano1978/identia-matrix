class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Fallos al escribir en el bucket de artefactos (S3, F5). En producción NO hay
  # fallback a disco: si S3 no responde, el artefacto no se da por publicado.
  # Los nombres van como String porque aws-sdk-s3 se carga en diferido
  # (require: false); cuando el error existe, la gema ya está cargada.
  rescue_from "Aws::Errors::ServiceError",            with: :artifact_write_failed
  rescue_from "Aws::Errors::MissingCredentialsError", with: :artifact_write_failed
  rescue_from "Seahorse::Client::NetworkingError",    with: :artifact_write_failed
  rescue_from ActiveStorage::IntegrityError,          with: :artifact_write_failed

  private

  def user_not_authorized
    flash[:alert] = "No tienes permisos para esta acción."
    redirect_back fallback_location: "/"
  end

  def artifact_write_failed(exception)
    Rails.logger.error("Fallo al escribir en el bucket de artefactos: #{exception.class}: #{exception.message}")
    redirect_back fallback_location: "/", alert: "No se ha podido publicar el artefacto."
  end
end
