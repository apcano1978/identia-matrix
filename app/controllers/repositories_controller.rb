# El eje de memoria: lo que TANK lee para no repetir decisiones ya tomadas.
class RepositoriesController < ApplicationController
  def show
    @client = Platform::Client.find_by!(slug: params[:client_slug])
    @repository = @client.repositories.find_by!(name: params[:name])
    @adrs = @repository.adrs.includes(:origin_initiative).order(:code)
    @history = history_for(@repository)
    @citations = @repository.citations.kind_code.includes(:citable)
  end

  private
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
