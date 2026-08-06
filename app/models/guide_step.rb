# Un paso de la guía de pruebas: lo que una persona tiene que recorrer.
#
# `evidence_origin` dice por qué el paso existe:
#
#   auto_verified  el criterio ya lo verificó SERAPH; el paso confirma.
#   sole_evidence  NADIE MÁS lo verifica. Si esta persona no lo recorre, el
#                  criterio se queda sin evidencia de ninguna clase.
#
# Y hay dos formas distintas de cerrarlo, que no se guardan juntas: RECORRIDO
# —alguien lo hizo— y EXIMIDO —un aprobador autorizó cerrarlo porque nadie
# podía hacerlo—.
class GuideStep < ApplicationRecord
  belongs_to :test_guide
  belongs_to :dod_criterion, optional: true
  belongs_to :walked_by_user, class_name: "Platform::User", optional: true
  belongs_to :exempted_by_user, class_name: "Platform::User", optional: true
  belongs_to :escalation, optional: true

  has_many :verdicts, dependent: :nullify
  has_many :opened_escalations, class_name: "Escalation",
                                dependent: :nullify,
                                inverse_of: :guide_step

  enum :evidence_origin, { auto_verified: 0, sole_evidence: 1 },
       prefix: :evidence, validate: true

  validates :position, presence: true,
                       uniqueness: { scope: :test_guide_id }
  validates :title, presence: true
  validate :exemption_must_be_authorized

  scope :in_order, -> { order(:position) }

  def walked? = walked_at.present?
  def exempted? = exempted_at.present?
  def settled? = walked? || exempted?

  # Bloquea GATE 2 si el criterio que cubre se declaró crítico. Se decide al
  # ESCRIBIR el contrato y lo revisa MORFEO, no al verificar — que es lo que
  # impide ajustarlo a conveniencia cuando hay prisa.
  def critical? = dod_criterion&.critical? || false

  private
    # Eximir es una decisión de otra persona, no del que está bloqueado: una
    # eximición sin quién y sin escalada es un paso saltado.
    def exemption_must_be_authorized
      return if exempted_at.blank?

      errors.add(:exempted_by_user, "hace falta para eximir un paso") if exempted_by_user_id.blank?
      errors.add(:escalation, "hace falta para eximir un paso") if escalation_id.blank?
    end
end
