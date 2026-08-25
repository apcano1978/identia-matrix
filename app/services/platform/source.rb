# La costura de la proyección: el segundo sitio con este patrón, junto al
# runtime de agentes y a la autenticación.
module Platform::Source
  module_function

  # `client` acota la fuente real a un solo cliente. La falsa lo ignora: sirve
  # el catálogo entero de la maqueta, que es de lo que está hecha.
  def current(client: nil)
    case ENV.fetch("MATRIX_PLATFORM_SOURCE", default_source)
    when "fake" then Platform::FakeSource
    when "platform" then Platform::HttpSource.new(client_platform_id: client&.platform_id)
    else
      raise ArgumentError,
            "MATRIX_PLATFORM_SOURCE debe ser `fake` o `platform`"
    end
  end

  # Sin construir la fuente: solo mira el interruptor.
  def real? = ENV.fetch("MATRIX_PLATFORM_SOURCE", default_source) == "platform"

  def default_source = Rails.env.production? ? "platform" : "fake"
end
