# Un documento o acta marcado como relevante para un evolutivo.
#
# Es un FILTRO, no una copia. Su AUSENCIA significa «heredada del cliente», que
# es lo visible por defecto: un documento sirve a varios evolutivos sin
# duplicarse en ninguno.
class InitiativeSource < ApplicationRecord
  belongs_to :initiative
  belongs_to :source, polymorphic: true

  SOURCE_TYPES = %w[Platform::Document Platform::Meeting].freeze

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :source_id, uniqueness: { scope: [ :initiative_id, :source_type ] }

  scope :documents, -> { where(source_type: "Platform::Document") }
  scope :meetings, -> { where(source_type: "Platform::Meeting") }
  scope :most_referenced, -> { order(refs_count: :desc, id: :asc) }

  # `refs_count` NO se deriva de las citas: cuenta las referencias a esta fuente
  # en el corpus indexado del cliente, que es otra cosa que las citas emitidas
  # dentro de artefactos de matrix. Un documento puede estar muy referenciado y
  # no haber sido citado nunca todavía. En F8 lo mantiene el indexador; hoy lo
  # siembra el catálogo. No «arreglarlo» convirtiéndolo en un contador.
end
