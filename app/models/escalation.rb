# El flujo detenido, esperando a una persona.
#
# Los tres primeros motivos los abre el SISTEMA. `unwalkable_step` lo abre una
# persona bloqueada y lo cierra OTRA autorizando: por eso lleva
# `opened_by_user` y `guide_step`, que los otros tres no usan.
class Escalation < ApplicationRecord
  belongs_to :initiative
  belongs_to :platform_client, class_name: "Platform::Client"
  belongs_to :opened_by_user, class_name: "Platform::User", optional: true
  belongs_to :opened_by_verification, class_name: "VerificationReport",
             optional: true
  belongs_to :guide_step, optional: true
  belongs_to :resolved_by_user, class_name: "Platform::User", optional: true
  belongs_to :human_note, optional: true

  enum :reason,
       { qa_cycles_exhausted: 0, inconclusive_environment: 1,
         morfeo_returns_exhausted: 2, unwalkable_step: 3 },
       validate: true

  validates :opened_at, presence: true
  # El único motivo que abre una persona es el único que exige saber quién.
  validates :opened_by_user, presence: true, if: :unwalkable_step?
  validates :guide_step, presence: true, if: :unwalkable_step?

  scope :open, -> { where(resolved_at: nil) }
  scope :resolved, -> { where.not(resolved_at: nil) }

  def open? = resolved_at.nil?
  def resolved? = !open?
end
