# El papel de una persona en un evolutivo concreto.
#
# Dos papeles, y la diferencia entre ellos es la que sostiene el flujo del ⊗
# irrecorrible de F6 §5:
#
#   observer   puede LEVANTAR LA MANO sobre un paso que no puede recorrer
#   approver   puede además AUTORIZAR que se cierre sin esa prueba
#
# No es el rol de acceso. `platform_users.role` lo sincroniza platform y dice
# quién puede entrar; esto dice qué puede hacer alguien dentro de un trabajo.
class InitiativeRole < ApplicationRecord
  belongs_to :initiative
  belongs_to :platform_user, class_name: "Platform::User"

  enum :role, { observer: 0, approver: 1 }, validate: true

  validates :platform_user_id, uniqueness: { scope: :initiative_id }

  scope :approvers, -> { where(role: :approver) }

  def to_s = "#{platform_user} · #{role} en #{initiative.code}"
end
