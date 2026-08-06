# El contrato contra el que se dictamina. Lo escribe SERAPH a partir de la spec
# de NEO y lo revisa MORFEO — sin esa revisión no se pasa a plan (invariante 5).
#
# Se versiona: dod-031 v2 no pisa a v1. Lo que ya se dictaminó siguió
# dictaminándose contra la versión que estaba delante.
class DefinitionOfDone < ApplicationRecord
  belongs_to :initiative
  belongs_to :authored_by_run, class_name: "AgentRun", optional: true
  belongs_to :reviewed_by_run, class_name: "AgentRun", optional: true
  belongs_to :artifact, optional: true
  belongs_to :derived_from_artifact, class_name: "Artifact", optional: true

  has_many :dod_criteria, dependent: :destroy
  has_many :verification_reports, dependent: :restrict_with_exception

  validates :code, presence: true,
                   uniqueness: { scope: [ :initiative_id, :version ] }
  validates :version, numericality: { greater_than_or_equal_to: 1 }

  scope :latest_first, -> { order(version: :desc) }

  # Invariante 5, en el modelo: sin revisión de MORFEO no se avanza a plan.
  def reviewed? = reviewed_by_run.present?

  def criteria_count = dod_criteria.size

  def to_s = "#{code} v#{version}"
end
