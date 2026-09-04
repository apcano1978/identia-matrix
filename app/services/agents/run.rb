# Ejecutar un agente y dejar constancia de lo que pasó.
#
# Es el punto por el que pasan las tres formas de lanzar un agente —la interfaz,
# el job y el recorrido de consola—, y existe porque las tres tienen que
# registrar lo mismo: la fila del run, su consumo y, si el agente produce
# artefacto, el artefacto publicado.
#
# ── Un fallo técnico no es un veredicto ────────────────────────────────────
#
# Que el brain responda 502, o que no responda, NO es un ✕ ni un `?` ni una
# escalada: es que la llamada no se pudo hacer. El run queda en `failed`, la
# etapa se ve fallida y una persona la relanza. Confundirlo con un dictamen
# contaminaría `qa_cycles_consumed`, que es lo que protege el invariante 7: solo
# un veredicto ✕ consume ciclo de QA, y un ciclo consumido por una avería de red
# acerca el evolutivo a la escalada por un motivo que no es suyo.
#
# ── Una sola ejecución viva por etapa ──────────────────────────────────────
#
# Lo impide la BASE DE DATOS, no este servicio: `idx_agent_runs_one_live` es un
# índice único parcial sobre (evolutivo, agente, propósito, iteración) para las
# filas `queued` y `running`. La interfaz, un relanzamiento manual y el reintento
# de un job pueden solaparse, y una comprobación en Ruby tiene una ventana entre
# el `exists?` y el `create`. Aquí solo se traduce el error de la base de datos a
# algo que la pantalla pueda decir.
module Agents
  class Run
    # Lo que produce cada propósito. Un agente cuyo propósito no está aquí
    # ejecuta y registra, pero no publica nada.
    ARTIFACT_KINDS = {
      "context" => :dossier, "spec" => :spec, "dod_pass" => :dod,
      "package" => :pkg, "verification" => :verify, "closure" => :close
    }.freeze

    AlreadyRunning = Class.new(StandardError)

    Result = Data.define(:agent_run, :result, :artifact)

    def self.call(...) = new(...).call

    def initialize(initiative:, agent:, purpose:)
      @initiative = initiative
      @agent = agent.to_s
      @purpose = purpose.to_s
    end

    def call
      run = start!
      result = Runtime.run(run)

      run.update!(status: :ok, finished_at: Time.current,
                  input_tokens: result.input_tokens,
                  output_tokens: result.output_tokens,
                  cost_cents: cost_cents(result),
                  brain_request_id: result.request_id)

      Result.new(agent_run: run, result: result, artifact: publish(run, result))
    rescue Runtime::Error => error
      # `run` puede no existir si el fallo fue al crearlo; en ese caso no hay
      # nada que marcar y la excepción sube tal cual.
      fail!(run, error) if defined?(run) && run&.persisted?
      raise
    end

    private
      attr_reader :initiative, :agent, :purpose

      # `config` guarda la configuración EFECTIVA con la que corre esta
      # ejecución. Desde P2 los ajustes se pueden cambiar, y sin esto un
      # artefacto publicado bajo una política quedaría inexplicable en cuanto la
      # política cambiara — y no se puede anotar después, porque es inmutable.
      # `agent_configs` contesta cómo se trabaja hoy; esta columna, cómo se hizo
      # esto.
      def start!
        AgentRun.create!(
          initiative: initiative, agent: agent, purpose: purpose,
          iteration: initiative.iteration,
          qa_cycle: initiative.qa_cycles_consumed,
          config: AgentConfig.effective_for(
            agent: agent, client: initiative.platform_client_id),
          code: next_code, status: :running, started_at: Time.current)
      rescue ActiveRecord::RecordNotUnique
        raise AlreadyRunning,
              "#{agent.upcase} ya está trabajando en #{initiative.code}"
      end

      # El número de pase distingue las ejecuciones del mismo agente a lo largo
      # de las iteraciones. No puede salir de `count + 1`: el índice único vive
      # sobre la iteración, no sobre el código, así que dos iteraciones podrían
      # producir el mismo.
      def next_code
        pass = initiative.agent_runs.where(agent: agent, purpose: purpose).count + 1
        "#{agent}/#{initiative.code}-#{purpose}-#{pass}"
      end

      # El coste llega en dólares y con decimales; la columna es en céntimos. Se
      # redondea al alza para que un agregado de muchas ejecuciones baratas no
      # acabe diciendo que no costaron nada.
      def cost_cents(result)
        usd = result.usage["cost_usd"]
        return nil if usd.blank?

        (usd.to_f * 100).ceil
      end

      def publish(run, result)
        kind = ARTIFACT_KINDS[purpose]
        return nil if kind.blank?

        Artifacts::Publish.call(
          initiative: initiative, kind: kind, body: result.body,
          produced_by_run: run, produced_at: run.started_at).artifact
      end

      def fail!(run, error)
        run.update!(status: :failed, finished_at: Time.current,
                    error: error.message.truncate(1000))
      end
  end
end
