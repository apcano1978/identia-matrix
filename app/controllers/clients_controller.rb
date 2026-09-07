# Los clientes, proyectados desde identia-platform.
#
# Solo lectura, y no por falta de tiempo: matrix nunca modifica un origen.
#
# Desde F11 esta sección **dejó de ser la puerta de entrada al trabajo**: el
# evolutivo y el repositorio cuelgan del proyecto. Lo que queda aquí es lo que es
# del cliente y de ningún proyecto —quién es, si está en preparación, cuándo se
# sincronizó y qué documentación tiene— más la lista de sus proyectos.
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

  # La ficha conserva lo que es DEL CLIENTE y de ningún proyecto: su
  # sincronización con platform, su admisión (P16) y sus documentos y reuniones.
  # El trabajo —evolutivos y repositorios— se ve en la ficha de cada proyecto.
  def show
    @client = Platform::Client.find_by!(slug: params[:slug])
    @projects = @client.projects.order(:slug)
                       .includes(initiatives: { initiative_repositories: :repository })
                       .to_a
  end
end
