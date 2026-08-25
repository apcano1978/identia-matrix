module Platform
  # El latido de la sincronización (F8 §A.5).
  #
  # Cada quince minutos, la misma convención que identia-platform: un cron a
  # frecuencia fija que consulta la base de datos para decidir qué toca, en vez
  # de una frecuencia por cliente escrita en el YAML.
  #
  # No se ejecuta con la fuente falsa: sincronizar el seed contra sí mismo no
  # hace nada útil y llenaría el event stream de ruido en desarrollo.
  class SyncJob < ApplicationJob
    queue_as :default

    def perform(client_id = nil)
      return unless Platform::Source.real?

      if client_id
        Platform::Sync.call(Platform::Client.find(client_id))
      else
        Platform::Sync.all
      end
    end
  end
end
