module ApplicationHelper
  # `Pagy::Backend` ya está en ApplicationController desde F0; el frontend hace
  # falta aquí para pintar el paginador. Solo lo usan los dos listados que crecen
  # sin techo: clientes y los evolutivos de un cliente.
  include Pagy::Frontend
end
