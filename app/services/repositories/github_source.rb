# Leer un repositorio de GitHub por su API. **No se clona y no se ejecuta
# nada**: matrix nunca tiene una copia del código de un cliente en su disco.
#
# Tres preguntas, y ninguna más:
#
#   head_sha     ¿en qué commit está la rama?  → el anclaje de GATE 1
#   files_count  ¿cuántos ficheros hay?        → el contador de la ficha
#   file         ¿qué dice este fichero?       → lo que TANK cita
#
# La credencial sale de `RepositoryCredential`, por cliente y de solo lectura.
# Sin credencial se intenta igual: los repositorios públicos responden, y los
# del propio workspace lo son. Un 404 sin credencial suele ser «es privado», no
# «no existe» — GitHub no distingue a propósito, para no filtrar qué repos
# privados hay.
class Repositories::GithubSource
  API = "https://api.github.com".freeze

  # Cortos: esto corre dentro de la indexación de un evolutivo, y si GitHub
  # tarda es preferible fallar y reintentar que dejar la etapa colgada.
  OPEN_TIMEOUT = 3
  TIMEOUT = 15

  Error = Class.new(StandardError)
  NotFound = Class.new(Error)

  def initialize(repository, location)
    @repository = repository
    @location = location
  end

  def name = "github"

  # El commit en el que está la rama ahora mismo. Se devuelve **corto, de siete
  # caracteres**, que es lo que la gramática de citas exige en `@<sha7>`: un sha
  # de cuarenta no parsea, y el sitio de convertirlo es este y no cada llamante.
  def head_sha(branch = @repository.default_branch)
    get("repos/#{@location.slug}/branches/#{branch}").dig("commit", "sha")&.first(7)
  end

  # Cuántos ficheros tiene el árbol en ese commit. Un solo `recursive=1`, que es
  # una llamada en vez de una por directorio.
  #
  # Solo `blob`: los `tree` son directorios y contarlos inflaría la cifra que la
  # ficha enseña como «ficheros».
  def files_count(sha)
    tree = get("repos/#{@location.slug}/git/trees/#{sha}", recursive: 1)

    # GitHub trunca los árboles enormes y lo dice. Se devuelve lo que hay, y el
    # llamante decide: mentir con una cifra parcial sin avisar sería peor.
    @truncated = tree["truncated"] == true
    tree.fetch("tree", []).count { |entry| entry["type"] == "blob" }
  end

  def truncated? = @truncated == true

  # El cuerpo de un fichero **en un commit concreto**, que es lo que hace que
  # una cita de código siga resolviendo aunque el repositorio avance.
  def file(path, sha)
    payload = get("repos/#{@location.slug}/contents/#{path}", ref: sha)
    return nil unless payload["encoding"] == "base64"

    Base64.decode64(payload.fetch("content")).force_encoding("UTF-8").scrub
  rescue NotFound
    nil
  end

  private

  def get(path, params = {})
    response = connection.get("/#{path}", params)

    raise NotFound, "#{@location} no responde en #{path}" if response.status == 404
    unless response.success?
      raise Error, "GitHub devolvió #{response.status} en #{path} para #{@location}"
    end

    JSON.parse(response.body)
  rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
    raise Error, "no se pudo alcanzar #{@location.host}: #{e.class}"
  end

  def connection
    @connection ||= Faraday.new(url: API) do |f|
      f.headers["Accept"] = "application/vnd.github+json"
      f.headers["X-GitHub-Api-Version"] = "2022-11-28"
      f.headers["Authorization"] = "Bearer #{token}" if token.present?
      f.options.open_timeout = OPEN_TIMEOUT
      f.options.timeout = TIMEOUT
    end
  end

  def token
    @token ||= RepositoryCredential.current_for(@repository.platform_client,
                                                @location.host)&.token
  end
end
