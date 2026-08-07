# frozen_string_literal: true

module Citations
  # Lo que el panel de procedencia necesita saber de un artefacto, calculado de
  # una vez. Existe para que la vista no tenga que decidir nada: recibe listas
  # ya ordenadas y un ratio ya comparado con su umbral.
  Panel = Data.define(:citations, :ratio, :code_groups, :excerpt, :conflicts) do
    def self.for(artifact)
      return empty if artifact.blank?

      citations = artifact.citations.in_order
                          .includes(:repository, :target).to_a

      new(citations: citations,
          ratio: DerivedRatio.call(citations,
                                   client: artifact.platform_client_id),
          code_groups: CodeGroups.call(citations),
          excerpt: excerpt_for(citations),
          conflicts: conflicts_for(citations))
    end

    def self.empty
      new(citations: [], ratio: DerivedRatio.for(nil), code_groups: [],
          excerpt: nil, conflicts: [])
    end

    # La primera cita de documento cuya fuente tenga cuerpo. Un PDF del que
    # nadie extrajo texto es un caso real: se salta, y si ninguna lo tiene el
    # bloque no se pinta.
    def self.excerpt_for(citations)
      citations.find do |citation|
        citation.kind_doc? && citation.target.try(:body).present?
      end
    end

    # Los conflictos abiertos en los que participa alguna cita de este
    # artefacto, desde cualquiera de los dos lados.
    def self.conflicts_for(citations)
      ids = citations.map(&:id)
      return [] if ids.empty?

      CitationConflict.unresolved
                      .where(derived_citation_id: ids)
                      .or(CitationConflict.unresolved.where(origin_citation_id: ids))
                      .includes(:derived_citation, :origin_citation,
                                :flagged_artifact)
                      .order(:detected_at)
    end
  end
end
