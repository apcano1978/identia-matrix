# frozen_string_literal: true

# Quién puede dar de alta un evolutivo.
#
# La regla no se escribe aquí: se pregunta a `Platform::User#may_access_matrix?`,
# que es donde vive entera desde F2 —rol con acceso, no deshabilitado, no
# ausente en platform— y la única respuesta a esa pregunta. Una segunda copia
# aquí podría discrepar de la primera, y discreparía en silencio.
class InitiativePolicy < ApplicationPolicy
  def show? = user&.may_access_matrix? || false

  # Abrir un evolutivo es de quien opera el sistema. No hace falta papel en el
  # evolutivo —todavía no existe— así que la pregunta es la de acceso.
  def create? = user&.may_access_matrix? || false

  # Lanzar al agente de la etapa. Es operar el sistema, igual que abrirlo: el
  # agente no decide nada por sí mismo —escribe un artefacto que después pasa
  # por MORFEO, por las puertas y por una persona—, así que no pide más papel
  # que el acceso.
  def run_agent? = user&.may_access_matrix? || false
end
