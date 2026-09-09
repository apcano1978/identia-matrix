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

  # Las dos pestañas. Los contadores se cuentan SIEMPRE, aunque solo se pinte
  # una lista: una pestaña que no dice cuántos hay detrás no invita a pulsarla, y
  # la de propios va a estar vacía hasta que exista «matrix interna».
  #
  # Por defecto, los de cliente: es lo que enseña el rediseño y es lo que hay.
  TABS = { "propios" => :own, "de-cliente" => :for_clients }.freeze

  def index
    @tab = TABS.key?(params[:tab]) ? params[:tab] : "de-cliente"
    @counts = { "de-cliente" => Project.for_clients.count,
                "propios" => Project.own.count }

    @pagy, @projects = pagy(
      Project.public_send(TABS.fetch(@tab)).order(:slug)
             .includes(:platform_client, :repositories,
                       initiatives: { initiative_repositories: :repository }),
      limit: PER_PAGE)
  end

  # El alta de un proyecto PROPIO. El porqué de que solo sean propios está en
  # `Projects::Open`; la pantalla lo explica enseñando la otra opción apagada,
  # que es donde ese porqué le sirve a alguien.
  def new
    authorize Project, :create?
  end

  def create
    authorize Project, :create?

    project = Projects::Open.call(slug: params[:slug], name: params[:name],
                                  actor: Current.user.email_address)

    redirect_to project_path(project), status: :see_other,
                notice: "Proyecto #{project.slug} abierto. Regístrale un repositorio " \
                        "para poder abrir su primer evolutivo."
  rescue Projects::Open::Refused, ActiveRecord::RecordInvalid => error
    redirect_to new_project_path, status: :see_other,
                alert: "No se ha abierto: #{message_for(error)}."
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

    # Los documentos SUBIDOS (F12). Los vigentes y los retirados por separado:
    # un retirado sale del ámbito de los evolutivos nuevos y sigue existiendo,
    # así que se enseña, apagado, en vez de desaparecer.
    documents = @project.project_documents.includes(:uploaded_by_user,
                                                    file_attachment: :blob)
                        .order(created_at: :desc).to_a
    @documents, @retired_documents = documents.partition { |d| !d.retired? }

    # Lo que podría entrar en el ámbito de un evolutivo nuevo (F12 · B5). Del
    # PROYECTO y no de un evolutivo: aquí todavía no hay ninguno, y esa es
    # justamente la razón de que `available_for` exista.
    @available_sources = Sources::Scope.available_for(@project)
                                       .values.flat_map(&:sources)
  end

  private
    # La unicidad del slug la defiende el índice de la tabla, no el servicio: es
    # el único sitio donde dos altas simultáneas no pueden colarse entre la
    # comprobación y la escritura. Aquí se traduce a algo legible, porque
    # «Slug ya está en uso» no dice qué hacer.
    def message_for(error)
      return error.message unless error.is_a?(ActiveRecord::RecordInvalid)

      if error.record.errors.of_kind?(:slug, :taken)
        "ya hay un proyecto que se llama #{params[:slug].inspect}, y el nombre " \
        "corto no se puede repetir: entra en las claves de artefacto"
      else
        error.record.errors.full_messages.to_sentence
      end
    end
end
