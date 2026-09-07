# Los proyectos: la raíz del modelo desde F11, y la puerta de entrada al trabajo.
#
# Un proyecto es DE CLIENTE cuando tiene uno detrás, y PROPIO cuando no. La ficha
# es la pantalla que explica el modelo: evolutivos en las filas, repositorios en
# las columnas.
#
# Antes esto colgaba de `Platform::Client`, que es una proyección de solo lectura
# de identia-platform. La ficha de cliente sigue existiendo —conserva lo que es
# suyo y de ningún proyecto— pero ya no es por donde se entra a trabajar.
class ProjectsController < ApplicationController
  # Generoso a propósito: la paginación existe para el día que un proyecto tenga
  # cincuenta evolutivos, no para partir la matriz en dos con cinco.
  PER_PAGE = 25

  def index
    @pagy, @projects = pagy(
      Project.order(:slug)
             .includes(:platform_client, :repositories,
                       initiatives: { initiative_repositories: :repository }),
      limit: PER_PAGE)
  end

  def show
    @project = Project.find_by!(slug: params[:slug])
    @repositories = @project.repositories.order(:name).to_a
    @pagy, @initiatives = pagy(
      @project.initiatives
              .includes(:stage_entries, :escalations, :artifacts,
                        initiative_repositories: :repository)
              .order(:code),
      limit: PER_PAGE)

    # El pie de la matriz cuenta sobre TODOS, no sobre la página: «2 de 5 tocan
    # más de uno» dejaría de ser cierto en la página dos.
    @multi_repo_count = @project.initiatives
                                .joins(:initiative_repositories)
                                .group("initiatives.id").having("count(*) > 1")
                                .count.size
    @initiatives_count = @project.initiatives.count

    # Para vincular un evolutivo nuevo a su proyecto de platform. Se llega por el
    # cliente, que es de quien son: un proyecto PROPIO no tiene ninguno, y el
    # formulario lo dirá en vez de enseñar un desplegable vacío.
    #
    # Los ausentes se quedan fuera: se pueden seguir citando desde artefactos ya
    # emitidos, pero no se empieza trabajo nuevo sobre algo que ya no existe.
    @platform_projects = @project.platform_client&.platform_projects
                                 &.where(missing_since: nil)&.order(:name) || []
  end
end
