# El eje de trabajo. **Nunca `project`**: la maqueta llama a esta vista así
# internamente, y la guarda de vocabulario hace fallar la suite si se cuela.
class InitiativesController < ApplicationController
  def show
    @client = Platform::Client.find_by!(slug: params[:client_slug])
    @initiative = @client.initiatives
                         .includes(:stage_entries, :escalations, :artifacts,
                                   :platform_project,
                                   initiative_repositories: :repository)
                         .find_by!(code: params[:code])

    # En ORDEN DE PIPELINE, no por fecha: el seed los crea en la misma
    # transacción y `created_at` no los distingue. El último de la lista es el
    # más avanzado, y es el que el visor abre por defecto.
    #
    # Dentro de cada tipo manda la VERSIÓN MÁS ALTA, que es la vigente — la
    # misma regla que aplica `Citations::Resolve` al atar una cita derivada.
    # Sin el desempate, con dos filas del mismo código el orden lo decidiría la
    # inserción y `artifact_tabs` elegiría una por casualidad.
    @artifacts = @initiative.artifacts.includes(:produced_by_run)
                            .sort_by { |a| [ Artifacts::Key::KINDS.index(a.kind.to_sym), a.version ] }
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

  private
    MODES = %i[rendered source diff].freeze

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
