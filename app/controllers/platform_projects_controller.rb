# El enlace profundo desde identia-platform.
#
# Desde la ficha de un proyecto en platform se tiene que poder abrir la spec, el
# DoD o el cierre técnico que produjo matrix. La forma más barata que cumple eso
# es un enlace resoluble, no una API:
#
#   https://matrix.identialabs.com/p/proj-2291
#
# Platform no necesita saber nada de matrix salvo la plantilla de esa URL, que
# construye con la `ref` que ya tiene en la mano. Y matrix no expone ninguna API
# nueva ni un contrato en sentido inverso.
#
# **Ni URLs firmadas de larga vida ni acceso anónimo**: un artefacto contiene
# decisiones técnicas de un cliente y no cuelga de un enlace adivinable. Quien
# no tenga sesión la inicia —este controlador sí hereda de ApplicationController,
# así que el `return_to` funciona y aterrizas aquí— y quien no tenga permiso
# sobre ese cliente recibe un 404.
class PlatformProjectsController < ApplicationController
  def show
    @platform_project = Platform::Project
                        .includes(initiatives: %i[platform_client artifacts])
                        .find_by(platform_project_ref: params[:platform_project_ref])

    # Ref desconocida y cliente ajeno colapsan en la MISMA rama, y es el punto:
    # un 403 confirmaría que el proyecto existe. Desde fuera son
    # indistinguibles.
    return head(:not_found) unless readable?(@platform_project)

    @initiatives = @platform_project.initiatives.order(:code)

    # Con un solo evolutivo no hay nada que elegir: se atraviesa.
    return redirect_to(initiative_path_for(@initiatives.first)) if @initiatives.one?

    @artifacts_by_initiative = @initiatives.index_with do |initiative|
      initiative.artifacts.sort_by { |a| [ Artifacts::Key::KINDS.index(a.kind.to_sym), a.version ] }
    end
  end

  private
    def readable?(platform_project)
      return false if platform_project.blank?

      clients = platform_project.initiatives.map(&:platform_client).uniq
      return Current.user&.may_access_matrix? if clients.empty?

      clients.all? { |client| Current.user&.may_read_client?(client) }
    end

    def initiative_path_for(initiative)
      client_initiative_path(initiative.platform_client, initiative)
    end
end
