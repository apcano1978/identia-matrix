# Job de diagnóstico: no hace nada salvo demostrar que el encolado funciona.
#
# Existe para poder comprobar de punta a punta que la aplicación, Redis y el
# worker se ven entre sí — tres cosas que pueden estar bien por separado y no
# funcionar juntas. Se encola desde la consola y se comprueba en /sidekiq.
#
# Desechable, como la página de diagnóstico: en F3 sobra.
module Diagnostics
  class PingJob < ApplicationJob
    queue_as :default

    def perform(label = "ping")
      Rails.logger.info("[diagnostics] #{label} · #{Time.current.iso8601}")
    end
  end
end
