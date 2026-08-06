# La costura de la proyección: el segundo sitio con este patrón, junto al
# runtime de agentes y a la autenticación.
module Platform::Source
  module_function

  def current
    case ENV.fetch("MATRIX_PLATFORM_SOURCE", default_source)
    when "fake" then Platform::FakeSource
    when "platform" then Platform::HttpSource
    else
      raise ArgumentError,
            "MATRIX_PLATFORM_SOURCE debe ser `fake` o `platform`"
    end
  end

  def default_source = Rails.env.production? ? "platform" : "fake"
end
