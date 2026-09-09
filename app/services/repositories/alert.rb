# frozen_string_literal: true

module Repositories
  # La alerta de que la indexación se rindió (F12 · B6).
  #
  # Se emite cuando los dos intentos se agotan. No es lo mismo que el motivo
  # escrito en la fila: aquel dice *qué* pasa —y se cura solo en cuanto un
  # intento funcione—; esto dice **que se dejó de intentar**, y es lo que hace
  # que un fallo de red no se convierta en un repositorio que lleva tres semanas
  # diciendo «en cola» sin que nadie sepa desde cuándo.
  #
  # Va al event stream, que es donde matrix cuenta lo que ha pasado. Los dos
  # servicios que la usan —el que lee un repositorio y el que ancla un
  # evolutivo— dicen lo mismo desde sitios distintos, así que vive aquí.
  #
  # ⚠ Un evento tiene una frontera o dos, nunca dos que se contradigan
  # (`an_event_belongs_to_one_or_two_frontiers_test`). El proyecto sale del
  # repositorio y el cliente del proyecto, así que no pueden discrepar.
  class Alert
    def self.record(repository:, reason:, initiative: nil)
      return if repository.nil?

      Event.create!(
        occurred_at: Time.current, actor: "matrix", kind: "repository_unreachable",
        project_id: repository.project_id,
        platform_client_id: repository.project.platform_client_id,
        initiative: initiative,
        message: "#{repository.name} · no se pudo leer tras dos intentos · #{reason}",
        payload: { repository: repository.name, reason: reason,
                   initiative: initiative&.code })
    end
  end
end
