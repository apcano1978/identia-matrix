# Una ejecución de un agente. Lo que se le pidió, lo que costó y cómo acabó.
#
# `purpose` no es decorativo: SERAPH interviene DOS veces con propósitos
# distintos —`dod_pass` antes de ejecutar y `verification` después— y sin esa
# distinción el índice único parcial le impediría verificar tras haber escrito
# el DoD.
class AgentRun < ApplicationRecord
  # Una sola ejecución viva por (evolutivo, agente, propósito, iteración). Lo
  # impide la base de datos, no un controlador: la interfaz, un relanzamiento
  # manual y el reintento de un job pueden solaparse.
  LIVE_STATUSES = %w[queued running].freeze

  belongs_to :initiative

  has_many :artifacts, foreign_key: :produced_by_run_id,
                       inverse_of: :produced_by_run, dependent: :nullify

  # ⚠ LOS DOS SON POSICIONALES: son columnas enteras. Lo que entra se ANEXA al
  # final y nada se intercala — intercalar cambiaría el significado de las filas
  # ya escritas sin tocarlas.
  #
  # `arquitecto` es el séptimo agente y llega en F11 · B8, en la etapa 1. Va el
  # último aunque trabaje el primero: el orden de este enum es el de aparición en
  # el código, no el del pipeline.
  enum :agent,
       { tank: 0, neo: 1, seraph: 2, morfeo: 3, trinity: 4, link: 5,
         arquitecto: 6 },
       prefix: true, validate: true

  # DOS propósitos para el ARQUITECTO, y no uno.
  #
  # `interview` es un turno de la conversación y NO publica nada; `requirements`
  # es el cierre y publica el acta. Con un solo propósito, `Agents::Run`
  # publicaría un artefacto por turno —lo que produce está en su tabla
  # `ARTIFACT_KINDS`— y el acta es el ESTADO ACUMULADO, no una serie de
  # documentos.
  enum :purpose,
       { context: 0, spec: 1, dod_pass: 2, review: 3, package: 4,
         verification: 5, closure: 6, interview: 7, requirements: 8 },
       prefix: true, validate: true
  enum :status, { queued: 0, running: 1, ok: 2, failed: 3 }, validate: true

  validates :code, presence: true, uniqueness: true

  scope :live, -> { where(status: LIVE_STATUSES) }
  scope :chronological, -> { order(:iteration, :qa_cycle, :id) }

  def live? = LIVE_STATUSES.include?(status)

  def duration_seconds
    return nil if started_at.blank? || finished_at.blank?

    (finished_at - started_at).to_i
  end

  def total_tokens = input_tokens.to_i + output_tokens.to_i
end
