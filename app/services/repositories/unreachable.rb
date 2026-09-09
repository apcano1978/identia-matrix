# frozen_string_literal: true

module Repositories
  # No se pudo hablar con el origen (F12 · B6).
  #
  # **Es lo único que se reintenta**, y por eso existe como error propio en vez de
  # dejar pasar el `GithubSource::Error` a secas. La distinción que hace es la que
  # decide qué hace el job:
  #
  #   sin origen legible          →  no se reintenta: no va a cambiar solo
  #   el origen no devolvió commit →  no se reintenta: el repositorio está vacío
  #   502, timeout, 500            →  `Unreachable`: se reintenta UNA vez
  #
  # Tras dos intentos el job para y deja la alerta. No hay latido que insista:
  # reintentar en bucle contra un repositorio que quizá nunca se pueda leer es
  # tráfico desatendido que no arregla nada, y el evolutivo parado con su motivo
  # a la vista es más útil que uno que lo intenta en silencio para siempre.
  Unreachable = Class.new(StandardError)
end
