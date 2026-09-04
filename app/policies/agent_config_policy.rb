# frozen_string_literal: true

# Quién puede cambiar cómo trabajan los agentes.
#
# La pregunta es la de acceso, como en el resto: `may_access_matrix?` es donde
# vive entera desde F2 y una segunda copia aquí podría discrepar en silencio.
#
# No hace falta más papel, y hay una razón de fondo: los ajustes que un cliente
# NO debe poder tocar no se protegen con un rol sino con `LOCKED_KEYS`, que se
# aplican pase quien pase. Pedir aquí un permiso especial daría la impresión de
# que el bloqueo depende de quién eres, y no depende: depende de qué ajuste es.
class AgentConfigPolicy < ApplicationPolicy
  def update? = user&.may_access_matrix? || false
end
