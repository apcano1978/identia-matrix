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
#
# **Este es el ÚNICO sitio de matrix que escribe `pinned_sha`**, y lo comprueba
# `test/architecture/solo_index_ancla_test.rb`. Leer un repositorio sin anclarlo
# —lo que hace falta al registrarlo, cuando aún no hay evolutivo— es otra cosa y
# vive en `Repositories::Probe`.
#
# ── No levanta: devuelve resultados (F12 · B6) ─────────────────────────────
#
# Un repositorio que no responde no puede tumbar la indexación de los otros dos
# del mismo evolutivo. Así que cada fallo se convierte en un `Result` con su
# motivo, y quien decide si eso merece un reintento es el JOB, mirando
# `retryable`. La tarea `matrix:index` los imprime y sigue, como siempre.
class Repositories::Index
  Result = Data.define(:repository, :pinned_sha, :files_count, :skipped, :retryable) do
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
    #
    # Y NO es reintentable: un `remote_url` que no se parsea no se va a parsear
    # dentro de treinta segundos.
    return skipped(link, "sin origen legible") if source.nil?

    sha = source.head_sha
    return skipped(link, "el origen no devolvió commit") if sha.blank?

    pin(link, sha)
    count(link, repository, source, sha)
  rescue Repositories::GithubSource::Error => error
    # Esto SÍ es reintentable: un 502 de GitHub no dice nada del repositorio.
    skipped(link, "el origen no respondió · #{error.message}", retryable: true)
  end

  # El anclaje se escribe **una sola vez**. `pinned_sha` ya puesto se respeta:
  # es la propiedad entera de esta pieza.
  def pin(link, sha)
    link.update!(pinned_sha: sha, first_linked_at: link.first_linked_at || Time.current) if link.pinned_sha.blank?
  end

  def count(link, repository, source, sha)
    files = source.files_count(link.pinned_sha)

    # `indexing_error: nil` al lograrlo: un motivo viejo que sobreviva al éxito
    # es peor que ninguno — la pantalla estaría explicando un fallo que ya no
    # existe.
    link.update!(indexed_files_count: files, indexed_at: Time.current,
                 indexing_error: nil)
    # El `head_sha` del repositorio SÍ avanza: es «dónde está ahora», no «con
    # qué se trabajó». Son dos preguntas distintas y por eso son dos columnas.
    repository.update!(head_sha: sha, files_count: files,
                       last_synced_at: Time.current, indexing_error: nil)

    Result.new(repository: repository, pinned_sha: link.pinned_sha,
               files_count: files, skipped: nil, retryable: false)
  end

  # El motivo se escribe en las DOS filas, y no es redundante: el del enlace
  # responde «por qué este evolutivo no ancló» y el del repositorio «si se puede
  # leer». Un 502 puntual deja el primero y no debería ensuciar el segundo… pero
  # sí lo escribe, porque es la única señal que tiene la ficha del repositorio y
  # el siguiente intento con éxito lo limpia.
  def skipped(link, reason, retryable: false)
    link.update!(indexing_error: reason)
    link.repository.update!(indexing_error: reason)

    Result.new(repository: link.repository, pinned_sha: nil, files_count: nil,
               skipped: reason, retryable: retryable)
  end

  # `TANK cirsa/ev-038 · indexed 1204 files · 3 sources linked`, que es lo que
  # la maqueta enseña.
  def record_event(results)
    indexed = results.reject(&:skipped)

    Event.create!(
      project_id: @initiative.project_id,
      occurred_at: Time.current, actor: @actor, kind: "repositories_indexed",
      initiative: @initiative, platform_client_id: @initiative.platform_client_id,
      message: "#{@initiative.code} · #{indexed.sum { |r| r.files_count.to_i }} ficheros · " \
               "#{indexed.size} de #{results.size} repositorios",
      payload: { results: results.map(&:to_s) })
  end
end
