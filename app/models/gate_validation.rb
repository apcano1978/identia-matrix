# GATE 2. Confirma que lo ejecutado sirve, y es REVERSIBLE por rechazo.
#
# Esa asimetría con GATE 1 está en el modelo: aquí no hay índice único por
# evolutivo, porque un evolutivo puede acumular varias validaciones si hubo
# rechazos. Un rechazo devuelve a NEO y sube `iteration`, pero NO consume ciclo
# de QA: no es un ✕ de SERAPH.
class GateValidation < ApplicationRecord
  belongs_to :initiative
  belongs_to :test_guide
  belongs_to :decided_by_user, class_name: "Platform::User"

  enum :decision, { validated: 0, rejected: 1 }, prefix: true, validate: true

  validates :decided_at, presence: true
  # Un rechazo sin motivo escrito es un rechazo que nadie puede atender.
  validates :rejection_note, presence: true, if: :decision_rejected?

  scope :chronological, -> { order(:decided_at) }

  def to_s = "#{decision} · #{decided_at&.iso8601}"
end
