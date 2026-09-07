# frozen_string_literal: true

# Quién puede abrir un proyecto propio. Mismo criterio que el alta de evolutivo y
# la de repositorio, y por la misma razón: quien entra en matrix trabaja en
# matrix.
#
# No hay `update?` ni `destroy?` —los hereda de `ApplicationPolicy`, que deniega—
# y eso no es un hueco: matrix no tiene ningún `update` fuera de `agent_configs`,
# y un proyecto no se corrige porque su slug ya está dentro de claves de
# artefacto emitidas.
class ProjectPolicy < ApplicationPolicy
  def show? = user&.may_access_matrix? || false

  def create? = user&.may_access_matrix? || false
end
