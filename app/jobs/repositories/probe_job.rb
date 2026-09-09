# Leer un repositorio recién registrado, en segundo plano (F12 · B6).
#
# **En un job y no en la petición**: leer un repositorio de cuatro mil ficheros
# son dos llamadas HTTP con quince segundos de tope cada una, y un alta que
# espera a eso es un alta que falla. El rediseño lo dice con las palabras que
# esta pantalla usa: *«deja el repositorio en cola de indexación»*.
#
# `queue_as :default` y no `:low`, por lo mismo que `ProjectDocuments::ExtractJob`:
# `low` tiene concurrencia 1 y es del latido desatendido. Esto lo espera alguien
# que acaba de pulsar «registrar».
module Repositories
  class ProbeJob < ApplicationJob
    queue_as :default

    # ⚠ DOS INTENTOS Y PARA. Un 502 de GitHub se reintenta una vez; si persiste,
    # el motivo ya está escrito en la fila —`Probe` lo anota antes de levantar—
    # y aquí solo se deja constancia.
    #
    # El bloque NO relanza, y es la misma razón que documenta `Agents::RunJob`:
    # relanzar tras agotar los intentos devuelve el job a Sidekiq y lo vuelve a
    # encolar en bucle. Se para, se ve, y `matrix:index` existe para rehacerlo.
    retry_on Repositories::Unreachable, attempts: 2, wait: 30.seconds do |job, error|
      repository = Repository.find_by(id: job.arguments.first)
      Repositories::Alert.record(repository: repository, reason: error.message)
    end

    # Si el repositorio ya no está, no hay nada que leer.
    discard_on ActiveRecord::RecordNotFound

    def perform(repository_id)
      Repositories::Probe.call(repository: Repository.find(repository_id))
    end
  end
end
