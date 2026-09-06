# Los clientes, proyectados desde identia-platform. La ficha es la pantalla que
# explica el modelo: evolutivos en las filas, repositorios en las columnas.
#
# Solo lectura, y no por falta de tiempo: matrix nunca modifica un origen.
class ClientsController < ApplicationController
  # Generoso a propósito: la paginación existe para el día que un cliente tenga
  # cincuenta evolutivos, no para partir la matriz en dos con cinco.
  PER_PAGE = 25

  def index
    @pagy, @clients = pagy(
      Platform::Client.active.order(:platform_id)
                      .includes(:repositories, :platform_projects,
                                initiatives: { initiative_repositories: :repository }),
      limit: PER_PAGE)

    # Resuelto una vez y pasado a las tarjetas: preguntarlo por fila serían
    # veinticinco consultas para pintar una marca.
    @admitted_ids = ClientAdmission.platform_ids
  end

  def show
    @client = Platform::Client.find_by!(slug: params[:slug])
    @repositories = @client.repositories.order(:name).to_a
    @pagy, @initiatives = pagy(
      @client.initiatives
             .includes(:stage_entries, :escalations, :artifacts,
                       initiative_repositories: :repository)
             .order(:code),
      limit: PER_PAGE)

    # El pie de la matriz cuenta sobre TODOS, no sobre la página: «2 de 5 tocan
    # más de uno» dejaría de ser cierto en la página dos.
    @multi_repo_count = @client.initiatives
                               .joins(:initiative_repositories)
                               .group("initiatives.id").having("count(*) > 1")
                               .count.size
    @initiatives_count = @client.initiatives.count

    # Para vincular un evolutivo nuevo a su proyecto de platform. Los ausentes
    # se quedan fuera: se pueden seguir citando desde artefactos ya emitidos,
    # pero no se empieza trabajo nuevo sobre algo que en platform ya no existe.
    @platform_projects = @client.platform_projects.where(missing_since: nil).order(:name)
  end
end
