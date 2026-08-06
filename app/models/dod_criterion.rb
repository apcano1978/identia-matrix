# Un criterio del DoD: la unidad sobre la que se dictamina.
#
# Dos nulos que significan algo, y no son un hueco por rellenar:
#
#   repository_id nulo → el criterio es «entre servicios». No hay repositorio
#                        donde comprobarlo, y por eso acaba en ⊗.
#   test_ref nulo      → LO NORMAL. La mayor parte de la comprobación es humana
#                        por diseño; sin test, el criterio también es ⊗.
class DodCriterion < ApplicationRecord
  belongs_to :definition_of_done
  belongs_to :repository, optional: true
  belongs_to :trace_citation, class_name: "Citation", optional: true

  has_many :verdicts, dependent: :destroy
  has_many :guide_steps, dependent: :nullify

  # Solo hay una clase de criterio obligatorio: el c0 que todo evolutivo
  # multi-repo lleva. `nil` es un criterio normal.
  enum :mandatory_kind, { multi_repo_compatibility: 0 }, prefix: :mandatory,
       validate: { allow_nil: true }

  validates :key, presence: true,
                  uniqueness: { scope: :definition_of_done_id }
  validates :statement, presence: true

  scope :critical, -> { where(critical: true) }
  scope :cross_service, -> { where(repository_id: nil) }

  # Verificable automáticamente. Que sea falso es el caso normal, no un fallo.
  def auto_verifiable? = test_ref.present? && repository_id.present?

  # Sin traza a origen no hay afirmación sostenible: invariante 4.
  def traced? = trace_citation_id.present?

  def to_s = "#{key} · #{statement}"
end
