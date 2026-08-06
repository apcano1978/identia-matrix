# Una cita derivada que contradice a su origen.
#
# Gana el ORIGEN. Siempre. No es una decisión que el sistema ofrezca: si el acta
# dice una cosa y la spec dice otra, la spec está mal.
#
# El artefacto afectado se marca para revisión DERIVANDO de aquí, no con una
# columna suya: la fila de un artefacto no se toca ni para metadatos.
class CitationConflict < ApplicationRecord
  ORIGIN_WINS = "origin_wins".freeze

  belongs_to :derived_citation, class_name: "Citation"
  belongs_to :origin_citation, class_name: "Citation"
  belongs_to :flagged_artifact, class_name: "Artifact", optional: true

  validates :detected_at, presence: true
  validate :levels_must_be_right

  scope :unresolved, -> { where(resolution: nil) }

  def resolved? = resolution.present?

  # INVARIANTE 8 · gana el ORIGEN. Resolver marca para revisión el artefacto que
  # hizo la afirmación DERIVADA, nunca la fuente. No hay método para lo
  # contrario: no es una decisión que el sistema ofrezca.
  def resolve!
    update!(resolution: ORIGIN_WINS,
            flagged_artifact: derived_citation.citable_as_artifact,
            detected_at: detected_at || Time.current)
  end

  private
    def levels_must_be_right
      if derived_citation.present? && !derived_citation.derived?
        errors.add(:derived_citation, "no es una cita derivada")
      end
      if origin_citation.present? && !origin_citation.origin?
        errors.add(:origin_citation, "no es una cita de origen")
      end
    end
end
