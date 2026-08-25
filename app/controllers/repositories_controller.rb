# El eje de memoria: lo que TANK lee para no repetir decisiones ya tomadas.
class RepositoriesController < ApplicationController
  def show
    @client = Platform::Client.find_by!(slug: params[:client_slug])
    @repository = @client.repositories.find_by!(name: params[:name])
    @adrs = @repository.adrs.includes(:origin_initiative).order(:code)
    @history = history_for(@repository)
    @citations = @repository.citations.kind_code.includes(:citable)
  end

  # Registrar un repositorio en un cliente (P1).
  #
  # Se piden ya `remote_url` y los dos campos de CI aunque nadie los use
  # todavía: la parte B necesita el primero para clonar y F10 los otros dos para
  # leer el CI. **Matrix no tiene ningún `update`**, así que lo que no se pida
  # aquí no se puede añadir después sin inventar una escritura nueva.
  #
  # Los tres son opcionales, y estar vacíos significa algo concreto: un
  # repositorio sin CI no admite verificación automática, y su ficha lo dice en
  # vez de fingir que verifica (`Repository#ci_configured?`).
  def create
    client = Platform::Client.find_by!(slug: params[:client_slug])
    authorize Repository, :create?

    repository = client.repositories.new(repository_params)

    if repository.save
      redirect_to client_repository_path(client, repository), status: :see_other,
                  notice: "Repositorio #{repository.name} registrado."
    else
      redirect_to client_path(client), status: :see_other,
                  alert: "No se ha registrado: #{repository.errors.full_messages.to_sentence}."
    end
  end

  private
    def repository_params
      params.permit(:name, :default_branch, :remote_url, :ci_provider, :ci_repo_slug)
            .with_defaults(default_branch: "main")
            .transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
    end

    Entry = Data.define(:link, :initiative, :base_sha, :executed_sha)

    # Del más reciente al más antiguo. Los dos sha salen de la FIRMA, no del
    # enlace: `base` es lo que se selló en GATE 1 y `executed` lo que Claude
    # Code dejó, y son dos cosas distintas por diseño.
    def history_for(repository)
      commits = GateSignatureCommit.where(repository: repository)
                                   .includes(gate_signature: :initiative)
                                   .index_by { |c| c.gate_signature.initiative_id }

      repository.initiative_repositories
                .includes(initiative: [ :platform_client, :stage_entries, :artifacts,
                                        :escalations ])
                .sort_by { |link| -(link.initiative.stage_changed_at ||
                                    link.initiative.opened_at).to_i }
                .map do |link|
        commit = commits[link.initiative_id]

        Entry.new(link: link, initiative: link.initiative,
                  base_sha: commit&.base_sha || link.pinned_sha,
                  executed_sha: commit&.executed_sha)
      end
    end
end
