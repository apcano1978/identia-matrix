# El eje de trabajo. **Nunca `project`**: la maqueta llama a esta vista así
# internamente, y la guarda de vocabulario hace fallar la suite si se cuela.
class InitiativesController < ApplicationController
  def show
    @project = Project.find_by!(slug: params[:project_slug])
    @initiative = @project.initiatives
                         .includes(:stage_entries, :escalations, :artifacts,
                                   :platform_project,
                                   initiative_repositories: :repository)
                         .find_by!(slug: params[:slug])

    # En ORDEN DE PIPELINE, no por fecha: el seed los crea en la misma
    # transacción y `created_at` no los distingue. El último de la lista es el
    # más avanzado, y es el que el visor abre por defecto.
    #
    # ⚠ Por `PIPELINE_ORDER` y NO por `KINDS`, que es lo que decía hasta B8.
    # `KINDS` es orden de almacenamiento —respalda un enum entero, así que lo
    # nuevo se anexa— y el acta entró la última trabajando la primera: ordenar
    # por ahí hacía que el visor abriera por el acta, o sea por el principio del
    # flujo presentado como el final.
    #
    # Dentro de cada tipo manda la VERSIÓN MÁS ALTA, que es la vigente — la
    # misma regla que aplica `Citations::Resolve` al atar una cita derivada.
    # Sin el desempate, con dos filas del mismo código el orden lo decidiría la
    # inserción y `artifact_tabs` elegiría una por casualidad.
    @artifacts = @initiative.artifacts.includes(:produced_by_run)
                            .sort_by { |a| [ Artifacts::Key.pipeline_position(a.kind), a.version ] }
                            .reverse
    @artifact = selected_artifact
    @versions = versions_of(@artifact)
    @mode = selected_mode
    @compared = compared_version
    @diff = Artifacts::Diff.call(@compared&.body_markdown, @artifact&.body_markdown) if @mode == :diff
    @refs = Citations::Panel.for(@artifact)
    @report = @initiative.verification_reports.order(:id).last
    @events = @initiative.events.recent.limit(Event::STREAM_SIZE * 2)
  end

  # Dar de alta un evolutivo (P1). `create` y nada más: matrix no edita ni borra.
  #
  # Nace en `need` y ahí espera. **No hay forma de avanzarlo desde la interfaz**,
  # y no se añade una: el pipeline lo mueven los agentes, que llegan en F9.
  def create
    project = Project.find_by!(slug: params[:project_slug])
    authorize Initiative, :create?

    # ⚠ LOS FICHEROS PRIMERO, y fuera de la transacción del alta. Un documento es
    # del PROYECTO, no del evolutivo: si el alta se niega —sin título, sin
    # repositorio— lo subido se queda, y el aviso lo dice. Deshacerlo obligaría a
    # volver a arrastrar los ficheros, que es lo único que el navegador no puede
    # rehacer solo.
    #
    # Y `authorize` con `ProjectDocument`, aparte: son dos permisos distintos y
    # dejar que uno arrastre al otro es como se cuelan los huecos.
    subida = upload_documents(project)
    initiative = Initiatives::Open.call(
      project: project,
      title: params[:title],
      # DENTRO del proyecto, nunca por id suelto: un `Repository.find` a secas es
      # la forma más fácil de cruzar la frontera sin darse cuenta.
      repositories: project.repositories.where(id: params[:repository_ids]),
      # Lo marcado y lo recién subido, por separado: «adjuntadas ahora · pasan a
      # ser fuentes de este evolutivo», pero adjuntar no es recortar. El porqué
      # de que sean dos parámetros está en `Initiatives::Open`.
      sources: chosen_sources(project),
      attached: subida.documents,
      platform_project: project.platform_client
                               &.platform_projects
                               &.find_by(id: params[:platform_project_id]),
      actor: Current.user.to_s)

    redirect_to project_initiative_path(project, initiative), status: :see_other,
                notice: opened_notice(initiative, subida)
  rescue Initiatives::Open::Refused => error
    redirect_to project_path(project), status: :see_other,
                alert: refused_alert(error, subida)
  end

  private
    MODES = %i[rendered source diff].freeze

    def upload_documents(project)
      return ProjectDocuments::UploadAll::Result.new(documents: [], refusals: []) \
        if Array(params[:files]).reject(&:blank?).empty?

      authorize ProjectDocument, :create?
      ProjectDocuments::UploadAll.call(project: project, files: params[:files],
                                       uploader: Current.user)
    end

    # Lo marcado en «documentación de partida», o `nil` si el formulario no traía
    # el bloque. La diferencia la usa `Initiatives::Open`: `nil` es «no me hables
    # de ámbito» y `[]` es «cero fuentes, a propósito».
    #
    # ⚠ Tres consultas ACOTADAS al proyecto, y el tipo no sale nunca de un
    # parámetro. Un `params[:source_type].constantize` habría sido más corto y
    # habría dejado que alguien nombrara cualquier clase del sistema.
    #
    # La frontera se vuelve a comprobar en el servicio, que es donde vive: esto
    # de aquí es la consulta, no la garantía.
    def chosen_sources(project)
      return nil unless params.key?(:scope)

      client_id = project.platform_client_id

      project.project_documents.where(id: params[:project_document_ids]).to_a +
        Platform::Document.where(platform_client_id: client_id,
                                 id: params[:platform_document_ids]).to_a +
        Platform::Meeting.where(platform_client_id: client_id,
                                id: params[:meeting_ids]).to_a
    end

    def opened_notice(initiative, subida)
      partes = [ "#{initiative.code} abierto" ]
      partes << "#{subida.count} documentos subidos" if subida.any?
      partes << if initiative.sources_scoped?
        "ámbito recortado a #{initiative.initiative_sources.count} fuentes"
      else
        "sin recortar el ámbito: entra todo, también lo que se suba después"
      end

      "#{partes.join(' · ')}. Espera a TANK, que llega en F9."
    end

    # Lo subido NO se pierde, y hay que decirlo: si no, quien vea «no se ha
    # abierto» dará por hecho que no pasó nada y volverá a arrastrar los mismos
    # ficheros.
    def refused_alert(error, subida)
      aviso = "No se ha abierto el evolutivo: #{error.message}."
      return aviso if subida.none?

      "#{aviso} Los #{subida.count} documentos sí se subieron al proyecto."
    end

    # Las pestañas `dod`, `verify` y `guide` de la maqueta llevan a pantallas
    # propias que son F6. Hasta entonces seleccionan qué artefacto enseña el
    # visor, que es lo mismo que hacen a medias y sin mentir.
    #
    # `version` desempata desde F5: un código puede tener varias filas, y sin
    # esto el `find` devolvería siempre la primera del orden, arbitrariamente.
    def selected_artifact
      return @artifacts.first if params[:artifact].blank?

      matching = @artifacts.select { |a| a.code == params[:artifact] }
      return @artifacts.first if matching.empty?

      by_version(matching, params[:version]) || matching.first
    end

    def by_version(artifacts, version)
      return nil if version.blank?

      artifacts.find { |a| a.version == version.to_i }
    end

    def versions_of(artifact)
      return [] if artifact.blank?

      @initiative.artifacts.where(code: artifact.code).order(:version).to_a
    end

    # Un artefacto de una sola versión no ofrece `diff`: no hay contra qué
    # comparar. Se degrada en vez de reventar, igual que las pestañas sin
    # artefacto de F3.
    def selected_mode
      mode = params[:view].to_s.to_sym
      return :rendered unless MODES.include?(mode)
      return :rendered if mode == :diff && @versions.size < 2

      mode
    end

    # Contra qué se compara. Por defecto, la versión inmediatamente anterior:
    # la maqueta rotula `diff v2↔v3` mientras el resto va por v4, y eso es lo
    # que no se copia — se ofrecen los pares reales.
    def compared_version
      return nil unless @mode == :diff

      by_version(@versions, params[:vs]) ||
        @versions[@versions.index(@artifact).to_i - 1]
    end
end
