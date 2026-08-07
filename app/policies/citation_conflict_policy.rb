# frozen_string_literal: true

# La primera policy real de matrix. Hasta F4 la aplicación era de solo lectura y
# la única guardia efectiva era «hay sesión»; resolver un conflicto es la
# primera escritura, y por tanto el primer sitio donde importa quién eres.
#
# Hereda de un ApplicationPolicy que DENIEGA por defecto, así que lo único que
# hay que declarar es lo permitido.
class CitationConflictPolicy < ApplicationPolicy
  # Quien puede entrar en matrix puede resolverlo. No hay un permiso más fino
  # porque no hay una decisión que tomar: resolver un conflicto de nivel no
  # elige nada —gana el origen, siempre—, solo reconoce lo que ya es cierto y
  # marca el artefacto derivado para el siguiente ciclo.
  def resolve? = user.present? && user.may_access_matrix?
end
