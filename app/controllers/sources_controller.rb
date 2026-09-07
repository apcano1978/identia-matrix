# «¿Qué puede leer un agente?», hecho pantalla. Es donde la frontera de cliente
# se vuelve inspeccionable en vez de ser una promesa del modelo.
#
# El nombre del controlador no es negociable: `ShellHelper::RAIL_SECTIONS` mapea
# `"sources" => :clients` comparando contra `controller_name`, y con cualquier
# otro nombre el rail se apagaría al entrar aquí.
class SourcesController < ApplicationController
  def index
    @project = Project.find_by!(slug: params[:project_slug])
    @initiative = @project.initiatives
                         .includes(initiative_repositories: :repository)
                         .find_by!(slug: params[:initiative_slug])

    @links = @initiative.initiative_repositories
                        .sort_by { |link| link.repository.name }
    @scoped = Sources::Scope.scoped(@initiative)
    @inherited = Sources::Scope.inherited(@initiative)
    @shared = Sources::Scope.shared(@initiative)
  end
end
