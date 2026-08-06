# El eje de TRABAJO: un evolutivo. Recorre las doce etapas, cruza uno o varios
# repositorios y muere cuando se publica.
#
# No es hijo de Repository ni padre suyo: se cruzan en `initiative_repositories`,
# que es la matriz evolutivo × repositorio de la ficha de cliente.
class Initiative < ApplicationRecord
  # Las doce etapas, en orden. El orden ES el dato: `Pipeline::Advance` avanza
  # por él y los saltos hacia atrás se miden contra él.
  STAGES = %w[
    need tank neo seraph_dod morfeo trinity
    gate_1 claude_code seraph_verification gate_2 link publication
  ].freeze

  # Tope de ciclos de QA. Un tercer ✕ no gasta un ciclo que no existe: escala.
  MAX_QA_CYCLES = 2

  belongs_to :platform_client, class_name: "Platform::Client"
  belongs_to :platform_project, class_name: "Platform::Project", optional: true

  has_many :initiative_repositories, dependent: :destroy
  has_many :repositories, through: :initiative_repositories
  has_many :stage_entries, dependent: :destroy
  has_many :agent_runs, dependent: :destroy
  has_many :events, dependent: :nullify
  has_many :escalations, dependent: :destroy
  has_many :human_notes, dependent: :destroy
  has_many :definitions_of_done, dependent: :destroy
  has_many :verification_reports, dependent: :destroy
  has_many :work_packages, dependent: :destroy
  has_many :gate_signatures, dependent: :destroy
  has_many :test_guides, dependent: :destroy
  has_many :gate_validations, dependent: :destroy
  has_many :artifacts, dependent: :destroy
  has_many :initiative_sources, dependent: :destroy

  enum :current_stage, STAGES.each_with_index.to_h, prefix: :at, validate: true
  enum :current_stage_status,
       { pending: 0, active: 1, done: 2, failed: 3, escalated: 4 },
       prefix: :status, validate: true

  validates :code, presence: true, uniqueness: true,
                   format: { with: /\Aev-\d{3,}\z/ }
  validates :title, presence: true
  validates :opened_at, presence: true
  validates :iteration, numericality: { greater_than_or_equal_to: 1 }
  validates :qa_cycles_consumed,
            numericality: { in: 0..MAX_QA_CYCLES }

  scope :open, -> { where.not(current_stage: :publication) }
  scope :for_client, ->(client) { where(platform_client_id: client) }

  # El número que comparten los artefactos del evolutivo: ev-031 → 31.
  def number = code.delete_prefix("ev-").to_i

  def multi_repo? = initiative_repositories.size > 1

  def qa_cycles_exhausted? = qa_cycles_consumed >= MAX_QA_CYCLES

  # La escalada abierta, si la hay. Un evolutivo detenido tiene exactamente una.
  def open_escalation = escalations.find_by(resolved_at: nil)

  def to_s = "#{code} · #{title}"
end
