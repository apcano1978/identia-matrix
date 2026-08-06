# Un par (repositorio, commit) dentro de una firma.
#
# Dos sha, y no se pueden colapsar en uno:
#
#   base_sha      SELLADO al firmar, copiado del paquete. La firma es
#                 autosuficiente aunque el paquete se vuelva a sellar
#                 más tarde (invariante 9).
#   executed_sha  EJECUTADO, y por eso nullable: se conoce después, cuando
#                 Claude Code termina y una persona lo confirma.
class GateSignatureCommit < ApplicationRecord
  belongs_to :gate_signature
  belongs_to :repository
  belongs_to :executed_confirmed_by, class_name: "Platform::User",
             optional: true

  validates :base_sha, presence: true
  validates :deploy_order, presence: true
  validates :repository_id, uniqueness: { scope: :gate_signature_id }

  scope :in_deploy_order, -> { order(:deploy_order) }

  def executed? = executed_sha.present?
end
