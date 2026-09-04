module Agents
  # Lanza un agente en segundo plano. Cola propia (`agents`), declarada desde F2
  # y estrenada aquí.
  class RunJob < ApplicationJob
    queue_as :agents

    # NO reintentar a nivel Sidekiq. `Agents::Run` crea la fila del run al
    # empezar, así que una excepción inesperada re-ejecutada crearía otra fila y
    # volvería a llamar al brain: se pagaría dos veces por el mismo trabajo. Los
    # fallos TRANSITORIOS sí se reintentan, acotados, con el `retry_on` de abajo,
    # que actúa a nivel ActiveJob y no consume el retry de Sidekiq.
    sidekiq_options retry: 0

    # El bloque es lo que importa: al agotar los intentos NO se re-lanza la
    # excepción. Si se relanzara, Sidekiq la recogería y volvería a encolar el
    # job en bucle. La ejecución ya quedó marcada como `failed`, así que aquí
    # solo se deja constancia.
    retry_on Runtime::Error, attempts: 2, wait: 30.seconds do |job, error|
      Rails.logger.warn(
        "[Agents::RunJob] reintentos agotados en #{job.arguments.inspect}: #{error.message}")
    end

    # Que ya haya una ejecución viva NO es un fallo que merezca reintento: es la
    # respuesta correcta del índice único a dos lanzamientos simultáneos. Se
    # descarta en silencio, porque el trabajo lo está haciendo el otro.
    discard_on Agents::Run::AlreadyRunning

    def perform(initiative_id, agent:, purpose:)
      initiative = Initiative.find_by(id: initiative_id)
      return if initiative.nil?

      Agents::Run.call(initiative: initiative, agent: agent, purpose: purpose)
    end
  end
end
