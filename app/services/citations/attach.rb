# frozen_string_literal: true

module Citations
  # La ÚNICA forma de crear una cita en el sistema.
  #
  # Antes de F4 esta lógica vivía tres veces —dos en el seed, una en el paseo de
  # la máquina de estados— y ya había divergido: la del paseo no resolvía el
  # `target` en absoluto, así que sus citas nacían sin fuente y nadie se
  # enteraba. Tres copias de una regla son tres reglas.
  #
  # Las citas se sacan PARSEANDO el cuerpo, no de una lista aparte. Es lo que
  # hace el sistema de verdad: un agente puede declarar una lista de citas en su
  # respuesta, pero matrix reparsea el cuerpo de todos modos, y una discrepancia
  # entre las dos listas es señal de que el agente se inventó una referencia.
  class Attach
    class << self
      # Todas las citas de un cuerpo de markdown, en el orden en que aparecen.
      # Idempotente: una segunda pasada no duplica.
      def body(citable:, body:, client:)
        references, = Parse.scan(body.to_s)

        references.uniq(&:raw).map.with_index do |reference, position|
          upsert(citable: citable, reference: reference, client: client,
                 position: position)
        end.compact
      end

      # Una cita suelta, de las que no salen de un cuerpo: la traza de un
      # criterio del DoD, la evidencia de un veredicto, el lado derivado de un
      # conflicto.
      def one(citable:, raw:, client:, position: nil, quote: nil)
        return nil if citable.blank? || raw.blank?

        reference = Parse.call(raw)
        return nil if reference.blank?

        upsert(citable: citable, reference: reference, client: client,
               position: position || citable.citations.count, quote: quote)
      end

      # Vuelve a intentar las citas que se quedaron sin fuente.
      #
      # No es un remiendo del seed: es la forma normal de que funcione la
      # memoria entre evolutivos. Una spec puede citar `[src:close/close-002#§3]`
      # antes de que ese cierre se publique —la afirmación es válida desde que
      # se escribe— y el vínculo aparece cuando el artefacto existe. La cita no
      # cambia; lo que cambia es que ahora hay contra qué resolverla.
      #
      # Solo mira las que están sin resolver: una cita ya atada no se re-ata,
      # porque su fuente no puede haber cambiado.
      def resolve_pending(scope = Citation.where(target_id: nil))
        scope.includes(:citable).filter_map do |citation|
          client_id = client_id_for(citation)
          next if client_id.blank?

          target = Resolve.call(citation.reference, client: client_id)
          next if target.blank?

          citation.update!(target: target)
          citation
        end
      end

      private
        # De quién es la cita. Cuelga de un artefacto, de un criterio o de un
        # veredicto, y solo el primero lleva el cliente encima.
        def client_id_for(citation)
          citable = citation.citable

          return citable.platform_client_id if citable.respond_to?(:platform_client_id)

          citable.try(:initiative)&.platform_client_id
        end

        # CURA la fila existente en vez de saltarla. La diferencia importa: con
        # un `next if exists?` —que es lo que hacía el seed— una base de
        # desarrollo ya sembrada conservaría para siempre las citas viejas con
        # `target` nulo, y ningún test lo detectaría porque los tests arrancan
        # limpios.
        def upsert(citable:, reference:, client:, position:, quote: nil)
          citation = citable.citations.find_or_initialize_by(raw: reference.raw)

          citation.source_kind = reference.kind
          citation.locator     = reference.locator
          citation.fragment    = reference.anchor
          citation.commit_sha  = reference.commit_sha
          citation.position    = position
          citation.repository  = Resolve.repository_for(reference, client: client)
          citation.target      = Resolve.call(reference, client: client)
          citation.quote       = quote if quote.present?

          citation.save!
          citation
        end
    end
  end
end
