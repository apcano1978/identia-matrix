# frozen_string_literal: true

# Correr un bloque con variables de entorno distintas, y devolverlas como
# estaban pase lo que pase.
#
# Matrix tiene CUATRO costuras que se eligen por variable de entorno
# —`MATRIX_AGENT_RUNTIME`, `MATRIX_PLATFORM_SOURCE`, `MATRIX_AUTH_SOURCE` y
# `MATRIX_REPOSITORY_SOURCE`—, así que probar la de al lado es una necesidad
# recurrente y no un apaño de un test suelto.
#
# El `ensure` no es ceremonia: una variable que se queda puesta contamina los
# tests siguientes, y el fallo aparece en otro fichero.
module EnvHelpers
  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
