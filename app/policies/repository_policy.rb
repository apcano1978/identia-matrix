# frozen_string_literal: true

# Quién puede registrar un repositorio en un cliente. Mismo criterio que el
# alta de evolutivo, y por la misma razón.
class RepositoryPolicy < ApplicationPolicy
  def show? = user&.may_access_matrix? || false

  def create? = user&.may_access_matrix? || false
end
