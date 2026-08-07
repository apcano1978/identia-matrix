# «¿Qué puede leer un agente?», hecho pantalla. Es donde la frontera de cliente
# se vuelve inspeccionable en vez de ser una promesa del modelo.
#
# El nombre del controlador no es negociable: `ShellHelper::RAIL_SECTIONS` mapea
# `"sources" => :clients` comparando contra `controller_name`, y con cualquier
# otro nombre el rail se apagaría al entrar aquí.
class SourcesController < ApplicationController
  def index
    @client = Platform::Client.find_by!(slug: params[:client_slug])
    @initiative = @client.initiatives
                         .includes(initiative_repositories: :repository)
                         .find_by!(code: params[:initiative_code])

    @links = @initiative.initiative_repositories
                        .sort_by { |link| link.repository.name }
    @scoped = Sources::Scope.scoped(@initiative)
    @inherited = Sources::Scope.inherited(@initiative)
    @shared = Sources::Scope.shared(@initiative)
  end
end
