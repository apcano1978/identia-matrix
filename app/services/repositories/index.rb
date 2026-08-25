# Anclar e indexar los repositorios de un evolutivo (F8 §B.3).
#
# Es lo que ocurre cuando un evolutivo entra en TANK, y hace dos cosas por cada
# repositorio que toca:
#
#   1. **Fijar el commit** en `initiative_repositories.pinned_sha`. A partir de
#      ahí, todo lo que TANK lea y cite de ese repositorio se ancla a ese commit.
#      Si el repositorio avanza mientras tanto, da igual: la spec habla de un
#      estado concreto del código y lo dice.
#   2. **Contar** lo que hay, que es lo que la ficha enseña.
#
# ⚠ **Un commit fijado NO se mueve.** Volver a indexar refresca el contador y el
# `head_sha` del repositorio, pero deja el anclaje donde estaba. Moverlo
# convertiría en mentira cada cita ya emitida contra él, dentro de artefactos
# que nadie puede reescribir.
class Repositories::Index
  Result = Data.define(:repository, :pinned_sha, :files_count, :skipped) do
    def to_s
      return "#{repository.name} · #{skipped}" if skipped

      "#{repository.name} · #{pinned_sha} · #{files_count} ficheros"
    end
  end

  def self.call(...) = new(...).call

  def initialize(initiative:, actor: "TANK")
    @initiative = initiative
    @actor = actor
  end

  def call
    results = @initiative.initiative_repositories.includes(:repository).map { |link| index(link) }
    record_event(results)
    results
  end

  private

  def index(link)
    repository = link.repository
    source = Repositories::Source.for(repository)

    # Nulo significa «este repositorio no se puede leer»: sin `remote_url`
    # legible o sin adaptador para su host. Se dice y se sigue con los demás, en
    # vez de tumbar la indexación del evolutivo entero.
    return skipped(repository, "sin origen legible") if source.nil?

    sha = source.head_sha
    return skipped(repository, "el origen no devolvió commit") if sha.blank?

    pin(link, sha)
    count(link, repository, source, sha)
  rescue Repositories::GithubSource::Error => error
    skipped(repository, error.message)
  end

  # El anclaje se escribe **una sola vez**. `pinned_sha` ya puesto se respeta:
  # es la propiedad entera de esta pieza.
  def pin(link, sha)
    link.update!(pinned_sha: sha, first_linked_at: link.first_linked_at || Time.current) if link.pinned_sha.blank?
  end

  def count(link, repository, source, sha)
    files = source.files_count(link.pinned_sha)

    link.update!(indexed_files_count: files, indexed_at: Time.current)
    # El `head_sha` del repositorio SÍ avanza: es «dónde está ahora», no «con
    # qué se trabajó». Son dos preguntas distintas y por eso son dos columnas.
    repository.update!(head_sha: sha, files_count: files, last_synced_at: Time.current)

    Result.new(repository: repository, pinned_sha: link.pinned_sha,
               files_count: files, skipped: nil)
  end

  def skipped(repository, reason)
    Result.new(repository: repository, pinned_sha: nil, files_count: nil, skipped: reason)
  end

  # `TANK cirsa/ev-038 · indexed 1204 files · 3 sources linked`, que es lo que
  # la maqueta enseña.
  def record_event(results)
    indexed = results.reject(&:skipped)

    Event.create!(
      occurred_at: Time.current, actor: @actor, kind: "repositories_indexed",
      initiative: @initiative, platform_client_id: @initiative.platform_client_id,
      message: "#{@initiative.code} · #{indexed.sum { |r| r.files_count.to_i }} ficheros · " \
               "#{indexed.size} de #{results.size} repositorios",
      payload: { results: results.map(&:to_s) })
  end
end
