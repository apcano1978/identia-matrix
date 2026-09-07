# «¿Qué puede leer un agente?», hecho pantalla. Es donde la frontera de proyecto
# se vuelve inspeccionable en vez de ser una promesa del modelo.
#
# El nombre del controlador no es negociable: `ShellHelper::RAIL_SECTIONS` mapea
# `"sources" => :projects` comparando contra `controller_name`, y con cualquier
# otro nombre el rail se apagaría al entrar aquí.
class SourcesController < ApplicationController
  def index
    @project = Project.find_by!(slug: params[:project_slug])
    @initiative = @project.initiatives
                         .includes(initiative_repositories: :repository)
                         .find_by!(slug: params[:initiative_slug])

    # La sección de fuentes heredadas es DEL CLIENTE, y un proyecto propio no
    # tiene ninguno. Se resuelve aquí para que la vista no tenga que preguntarlo
    # a través de dos asociaciones.
    @client = @project.platform_client

    @links = @initiative.initiative_repositories
                        .sort_by { |link| link.repository.name }
    @scoped = Sources::Scope.scoped(@initiative)
    @inherited = Sources::Scope.inherited(@initiative)
    @shared = Sources::Scope.shared(@initiative)
  end
end
