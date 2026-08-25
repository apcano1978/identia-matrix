# La costura de lectura de código: el cuarto sitio con este patrón, junto al
# runtime de agentes, la proyección de platform y la autenticación.
#
# ⚠ **Matrix lee el código por HTTP, no clonando**, y eso se aparta de lo que
# escribió F8 §B. El porqué está en «Lo que apareció al ejecutarla»: un clon
# exige ejecutar `git`, y el invariante 2 —comprobado con un test que hace grep
# de `Open3`, `system(` y compañía sobre `app/` y `lib/`— lo prohíbe. F10 se
# reescribió entera para dejar de ejecutar cosas sobre código de cliente y
# celebró que eso dejara a matrix con UNA sola excepción; clonar la habría
# devuelto a dos.
#
# Consecuencia que hay que aceptar: hace falta un adaptador por proveedor. Es el
# mismo precio que F10 ya decidió pagar para leer el CI, y por eso la interfaz
# está aquí y no dentro del de GitHub.
module Repositories::Source
  Unsupported = Class.new(StandardError)

  ADAPTERS = { "github.com" => "Repositories::GithubSource" }.freeze

  module_function

  # `nil` si el repositorio no dice dónde vive o su host no tiene adaptador.
  # Nulo significa «este repositorio no se puede indexar», y su ficha lo dice en
  # vez de fingir que sí — la misma forma que tiene el CI de decir que no
  # verifica (F10 §4).
  def for(repository)
    return Repositories::FakeSource.new(repository) unless real?

    location = Repositories::Remote.parse(repository.remote_url)
    return nil if location.nil?

    adapter = ADAPTERS[location.host]
    return nil if adapter.nil?

    adapter.constantize.new(repository, location)
  end

  def real? = ENV.fetch("MATRIX_REPOSITORY_SOURCE", default_source) == "remote"

  def default_source = Rails.env.production? ? "remote" : "fake"
end
