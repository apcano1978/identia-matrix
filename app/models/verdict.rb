# El dictamen sobre un criterio. Cuatro valores, y la diferencia entre ellos es
# donde está el valor del sistema:
#
#   met         ✓  se cumple, con evidencia
#   unmet       ✕  no se cumple — el ÚNICO que consume ciclo de QA
#   inconclusive ?  no se pudo determinar: el entorno no dio respuesta
#   unsupported ⊗  nada puede verificarlo automáticamente; lo cubre una persona
#
# Un `?` no es un `✕`: significa que no sabemos, y devolver a NEO por algo que
# no sabemos es fabricar trabajo.
class Verdict < ApplicationRecord
  GLYPHS = {
    "met" => "✓", "unmet" => "✕", "inconclusive" => "?", "unsupported" => "⊗"
  }.freeze

  belongs_to :verification_report
  belongs_to :dod_criterion
  belongs_to :evidence_citation, class_name: "Citation", optional: true
  # Los ⊗ no llevan evidencia sino redirección al paso de guía que los cubre.
  belongs_to :guide_step, optional: true

  enum :result,
       { met: 0, unmet: 1, inconclusive: 2, unsupported: 3 }, validate: true

  validates :dod_criterion_id,
            uniqueness: { scope: :verification_report_id }

  scope :consuming, -> { where(result: :unmet) }

  def glyph = GLYPHS.fetch(result)

  # Invariante 4: ninguna afirmación sobre el código sin fichero, repositorio y
  # commit. Un ✓ sin evidencia citable no es un ✓ defendible.
  def evidenced? = evidence_citation_id.present?
end
