# El paso de un evolutivo por una etapa. La FUENTE DE VERDAD del recorrido:
# `initiatives.current_stage` es solo un caché recomputable a partir de aquí.
#
# Un retorno no sobrescribe: INSERTA una fila nueva con `iteration + 1`. Ese es
# el mecanismo entero por el que el historial sobrevive a los ciclos de QA, y
# por eso el índice único es (evolutivo, etapa, iteración) y no (evolutivo,
# etapa).
class StageEntry < ApplicationRecord
  belongs_to :initiative

  enum :stage, Initiative::STAGES.each_with_index.to_h, prefix: :at,
       validate: true
  enum :status, { pending: 0, active: 1, done: 2, failed: 3, escalated: 4 },
       validate: true

  validates :iteration, numericality: { greater_than_or_equal_to: 1 }
  validates :stage, uniqueness: { scope: [ :initiative_id, :iteration ] }

  scope :chronological, -> { order(:iteration, :stage) }

  # La posición de la etapa en la tira de doce.
  def position = Initiative::STAGES.index(stage)

  def elapsed_seconds
    return nil if entered_at.blank?

    ((exited_at || Time.current) - entered_at).to_i
  end
end
