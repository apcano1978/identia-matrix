# El dictamen de SERAPH sobre un DoD. Aquí vive el invariante 7, que es la pieza
# que distingue este sistema de un gestor de tareas.
class VerificationReport < ApplicationRecord
  belongs_to :initiative
  belongs_to :definition_of_done
  belongs_to :agent_run, optional: true
  belongs_to :artifact, optional: true

  has_many :verdicts, dependent: :destroy
  has_many :ci_checks, dependent: :destroy
  has_many :test_guides, dependent: :restrict_with_exception
  has_many :opened_escalations, class_name: "Escalation",
                                foreign_key: :opened_by_verification_id,
                                inverse_of: :opened_by_verification,
                                dependent: :nullify

  enum :outcome, { conforme: 0, returned: 1, escalated: 2 }, prefix: true,
       validate: true

  validates :code, presence: true, uniqueness: true

  scope :chronological, -> { order(:iteration, :qa_cycle, :id) }

  # INVARIANTE 7. Solo ✕ consume ciclo de QA. `inconclusive` (?) y `unsupported`
  # (⊗) NO cuentan: confundirlos con ✕ haría que NEO escribiera specs para
  # arreglar bugs que no existen, que es el error más caro que el sistema puede
  # cometer.
  #
  # Está concentrado aquí, y no repartido por los servicios de pipeline, para
  # que un solo test lo proteja. No hay tabla `qa_cycles`: sería derivable de
  # esto, y un dato derivable que se almacena es un dato que se desincroniza.
  def consumes_cycle? = verdicts.any?(&:unmet?)

  def verdict_counts = verdicts.group(:result).count

  def unmet_verdicts = verdicts.select(&:unmet?)
  def inconclusive_verdicts = verdicts.select(&:inconclusive?)
  def unsupported_verdicts = verdicts.select(&:unsupported?)

  # El semáforo se compone de TODOS los checks obligatorios, no solo de la
  # suite: un lint en rojo con los tests en verde sigue siendo un desarrollo que
  # va a explotar.
  def ci_status
    statuses = ci_checks.map(&:status)
    return "unavailable" if statuses.empty? || statuses.include?("unavailable")

    statuses.include?("red") ? "red" : "green"
  end

  def to_s = code
end
