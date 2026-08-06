# La página de estado del entorno. Sin autenticar y solo montada en local — el
# porqué está en config/routes.rb.
#
# Sobrevive a F3, que era la duda que dejó abierta F1. Lo que NO se hace es
# mudarla a `/up`: el healthcheck tiene que ser barato, y uno que consulte Redis
# y Sidekiq deja de responder justo el día que hace falta leerlo.
class DiagnosticsController < ApplicationController
  layout "bare"

  allow_unauthenticated_access

  def show
    @checks = EnvironmentCheck.all
  end
end
