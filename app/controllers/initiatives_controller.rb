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
    @artifacts = @initiative.artifacts.includes(:produced_by_run)
                            .sort_by { |a| Artifacts::Key::KINDS.index(a.kind.to_sym) }
                            .reverse
    @artifact = selected_artifact
    @report = @initiative.verification_reports.order(:id).last
    @events = @initiative.events.recent.limit(Event::STREAM_SIZE * 2)
  end

  private
    # Las pestañas `dod`, `verify` y `guide` de la maqueta llevan a pantallas
    # propias que son F6. Hasta entonces seleccionan qué artefacto enseña el
    # visor, que es lo mismo que hacen a medias y sin mentir.
    def selected_artifact
      return @artifacts.find { |a| a.code == params[:artifact] } || @artifacts.first if
        params[:artifact].present?

      @artifacts.first
    end
end
