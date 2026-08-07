# frozen_string_literal: true

module Citations
  # Resolver un conflicto de nivel. INVARIANTE 8: gana el ORIGEN.
  #
  # Hace exactamente dos cosas, y ninguna más:
  #
  #   · Registra que gana el origen y deja marcado para revisión el artefacto
  #     que hizo la afirmación derivada.
  #   · Lo cuenta en el stream de actividad, que es lo que lo hace visible.
  #
  # No corrige nada. Marcar no es arreglar: el artefacto sigue siendo inmutable
  # y lo que corrige es el siguiente ciclo, cuando NEO reescriba la spec. Y el
  # marcado NO se escribe en el artefacto —se deriva de `flagged_artifact_id`—,
  # porque la fila de un artefacto no se toca ni para metadatos.
  #
  # UN SOLO MÉTODO PÚBLICO, y es deliberado: no existe forma de resolver un
  # conflicto a favor del derivado porque no es una decisión que el sistema
  # ofrezca. Hay un test estructural que lo comprueba.
  class ResolveConflict
    def self.call(conflict:, by: nil)
      return conflict if conflict.resolved?

      ActiveRecord::Base.transaction do
        conflict.resolve!
        record_event(conflict, by)
      end

      conflict
    end

    def self.record_event(conflict, user)
      artifact = conflict.flagged_artifact
      return if artifact.blank?

      Event.create!(
        occurred_at: Time.current, actor: "CONFLICTO", kind: "activity",
        initiative: artifact.initiative,
        platform_client: artifact.platform_client,
        message: "gana el ORIGEN sobre " \
                 "#{conflict.derived_citation.compact} · #{artifact.code} " \
                 "marcado para revisión#{user ? " por #{user.email_address}" : ''}")
    end
    private_class_method :record_event
  end
end
