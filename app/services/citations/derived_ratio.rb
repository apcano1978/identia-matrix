# frozen_string_literal: true

module Citations
  # Cuánto de lo que afirma un artefacto se apoya en el trabajo del propio
  # sistema, y no en material de origen.
  #
  # Es el aviso menos urgente y el más interesante de todos: no dice que algo
  # esté mal, dice que el corpus empieza a alimentarse de sí mismo. Por eso es
  # un aviso y no un bloqueo.
  #
  # La política vive bajo MORFEO —`morfeo.revision.derived_ratio_threshold`—
  # porque es una decisión de revisión, y así hereda el override por cliente sin
  # que este servicio tenga que saber nada de clientes.
  class DerivedRatio
    # El 25 % de la maqueta, que avisa con exactamente 3 de 12. De respaldo:
    # `AgentConfig.effective_for` devuelve `{}` cuando no hay nada sembrado, y
    # un umbral ausente no puede significar «nunca avises».
    DEFAULT_THRESHOLD = 0.25

    NOTICE = "%{derived} de %{total} citas son derivadas. " \
             "El corpus empieza a alimentarse de sí mismo."

    Ratio = Data.define(:origin, :derived, :total, :threshold) do
      def ratio = total.zero? ? 0.0 : derived.fdiv(total)

      # INCLUSIVE: la maqueta avisa con 3 de 12, que es el 25 % justo. Con `>`
      # el caso que la maqueta dibuja no saltaría.
      def over? = total.positive? && ratio >= threshold

      def notice = format(NOTICE, derived: derived, total: total)
    end

    class << self
      def for(artifact)
        return empty if artifact.blank?

        call(artifact.citations, client: artifact.platform_client_id)
      end

      def call(citations, client: nil)
        citations = citations.to_a
        derived = citations.count(&:derived?)

        Ratio.new(origin: citations.size - derived, derived: derived,
                  total: citations.size, threshold: threshold_for(client))
      end

      def threshold_for(client)
        settings = AgentConfig.effective_for(agent: :morfeo, client: client)

        settings.dig("revision", "derived_ratio_threshold") || DEFAULT_THRESHOLD
      end

      private
        def empty
          Ratio.new(origin: 0, derived: 0, total: 0,
                    threshold: DEFAULT_THRESHOLD)
        end
    end
  end
end
