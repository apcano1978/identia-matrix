# frozen_string_literal: true

# Cargar las tareas de rake UNA vez por proceso, y que dé igual cuántos ficheros
# de test las necesiten.
#
# `load_tasks` reevalúa el fichero entero, y **Rake ENCADENA las acciones de una
# tarea redefinida en vez de reemplazarlas**: tras la segunda carga, cada
# invocación ejecuta el cuerpo dos veces. Con una variable de clase por test eso
# no se ve —cada fichero carga una sola vez—, pero en cuanto dos ficheros prueban
# tareas, el segundo duplica las del primero y el síntoma aparece en el que corra
# después: una tarea idempotente se queja de que su efecto ya estaba hecho.
#
# La guarda tiene que ser del PROCESO, no de la clase. Por eso vive aquí.
module RakeHelpers
  class << self
    attr_accessor :loaded
  end

  def load_rake_tasks_once
    return if RakeHelpers.loaded

    IdentiaMatrix::Application.load_tasks
    RakeHelpers.loaded = true
  end
end
