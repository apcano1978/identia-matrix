# Cierra la puerta trasera de Active Storage.
#
# Los controladores de proxy de Active Storage heredan de
# `ActiveStorage::BaseController`, **no de `ApplicationController`**: ni el
# `require_authentication` del concern ni las policies les aplican. Sin esto,
# cualquiera con una URL firmada descarga el artefacto de cualquier cliente sin
# tener sesión. Es una puerta que hoy no abre nadie —ninguna vista genera URLs
# de blob, el visor renderiza en servidor— pero está abierta, y P3 va de eso.
#
# Tres cosas, y las tres importan:
module ArtifactAccess
  extend ActiveSupport::Concern

  included do
    before_action :require_artifact_access
    after_action :forbid_shared_caching
  end

  private
    def require_artifact_access
      artifact = artifact_for_blob
      return head(:not_found) if artifact.blank?

      head(:not_found) unless ArtifactPolicy.new(artifact_reader, artifact).show?
    end

    # `ProxyController#show` hace `http_cache_forever public: true`. Con
    # Thruster delante y kamal-proxy detrás, una respuesta `public` se puede
    # servir SIN VOLVER A PASAR POR RAILS, y la comprobación de arriba quedaría
    # de adorno a partir de la segunda petición. Es la trampa más fácil de no
    # ver de todo el bloque.
    #
    # Va en `after_action` y no antes: la acción escribe su propia cabecera de
    # caché, así que ponerla primero no serviría de nada.
    def forbid_shared_caching
      response.headers["Cache-Control"] = "private, no-store"
    end

    # Matrix no guarda otra cosa que artefactos: un blob que no cuelgue de uno
    # ya es una anomalía, y se trata como inexistente.
    def artifact_for_blob
      attachment = ActiveStorage::Attachment.find_by(blob_id: @blob&.id,
                                                     record_type: "Artifact")
      attachment&.record
    end

    # La sesión se reanuda a mano: aquí no hay concern de autenticación, y
    # `ActiveStorage::DisableSession` ha puesto `session_options[:skip]`.
    def artifact_reader
      session_id = cookies.signed[:session_id]
      return nil if session_id.blank?

      Session.find_by(id: session_id)&.platform_user
    end
end
