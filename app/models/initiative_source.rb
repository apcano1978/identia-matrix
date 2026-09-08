# Un documento o acta marcado como relevante para un evolutivo.
#
# Es un FILTRO, no una copia. Su AUSENCIA significa «todo lo disponible», que es
# lo visible por defecto: un documento sirve a varios evolutivos sin duplicarse
# en ninguno. Qué es «todo lo disponible» lo dice `Sources::Scope.in_scope`.
class InitiativeSource < ApplicationRecord
  belongs_to :initiative
  belongs_to :source, polymorphic: true

  # Los tres tipos que se pueden acotar. `ProjectDocument` entró en F12: un
  # documento subido al proyecto se acota igual que uno de platform, porque para
  # un evolutivo son la misma cosa —material de ORIGEN que puede citar—.
  DOCUMENT_TYPES = %w[Platform::Document ProjectDocument].freeze
  SOURCE_TYPES = (DOCUMENT_TYPES + %w[Platform::Meeting]).freeze

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :source_id, uniqueness: { scope: [ :initiative_id, :source_type ] }

  # ⚠ `documents` mira DOS tipos, no uno. Un documento es un documento venga de
  # donde venga, y la pantalla de fuentes los cuenta juntos: partirlos por
  # procedencia sería enseñar la fontanería.
  #
  # La unicidad sigue siendo por `[initiative, source_type, source_id]`, y tiene
  # que serlo: los ids de las dos tablas son independientes y el 7 de una no
  # tiene nada que ver con el 7 de la otra.
  scope :documents, -> { where(source_type: DOCUMENT_TYPES) }
  scope :meetings, -> { where(source_type: "Platform::Meeting") }
  scope :most_referenced, -> { order(refs_count: :desc, id: :asc) }

  # `refs_count` NO se deriva de las citas: cuenta las referencias a esta fuente
  # en el corpus indexado del cliente, que es otra cosa que las citas emitidas
  # dentro de artefactos de matrix. Un documento puede estar muy referenciado y
  # no haber sido citado nunca todavía. En F8 lo mantiene el indexador; hoy lo
  # siembra el catálogo. No «arreglarlo» convirtiéndolo en un contador.
end
