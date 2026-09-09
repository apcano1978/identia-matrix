# Anclar e indexar los repositorios de un evolutivo, en segundo plano (F12 · B6).
#
# **Esto es lo que cierra P23.** `Repositories::Index` existía desde F8 y la
# llamaba una sola cosa en todo el código: la tarea `matrix:index`, a mano. Sin
# ella `pinned_sha` queda nulo, `Runtime::Request#repositories_of` —que solo
# manda los anclados— deja el material sin un solo repositorio, y TANK escribe su
# dossier sin haber visto una línea de código. No falla: acierta plausible.
#
# Se encola al abrir el evolutivo, que es cuando existen los enlaces que hay que
# anclar. `matrix:index` se queda para reindexar a mano.
module Repositories
  class IndexJob < ApplicationJob
    queue_as :default

    # ⚠ DOS INTENTOS Y PARA, igual que `ProbeJob`. El bloque no relanza: hacerlo
    # devolvería el job a Sidekiq en bucle, y el motivo ya está escrito en las
    # filas —`Index` lo anota en cada intento—. Lo que añade la alerta es la
    # fecha en la que se dejó de intentar.
    retry_on Repositories::Unreachable, attempts: 2, wait: 30.seconds do |job, error|
      initiative = Initiative.find_by(id: job.arguments.first)
      next if initiative.nil?

      initiative.initiative_repositories.includes(:repository).each do |link|
        next if link.pinned?

        Repositories::Alert.record(repository: link.repository, initiative: initiative,
                                   reason: error.message)
      end
    end

    discard_on ActiveRecord::RecordNotFound

    # `Repositories::Index` no levanta: devuelve un resultado por repositorio,
    # porque uno que no responda no puede tumbar la indexación de los otros dos
    # del mismo evolutivo. Quien decide qué merece reintento es esto, y solo lo
    # merece lo que el servicio marcó como `retryable` — un 502, no un
    # `remote_url` que no se parsea.
    def perform(initiative_id)
      initiative = Initiative.find(initiative_id)
      results = Repositories::Index.call(initiative: initiative, actor: "matrix")

      fallidos = results.select(&:retryable)
      return if fallidos.empty?

      raise Repositories::Unreachable,
            fallidos.map { |result| "#{result.repository.name}: #{result.skipped}" }.join(" · ")
    end
  end
end
