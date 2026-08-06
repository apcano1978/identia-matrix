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
end
