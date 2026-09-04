# frozen_string_literal: true

# Responde a una sola pregunta: **¿está el entorno entero en pie?**
#
# Cada comprobación devuelve un estado del vocabulario de glifos de matrix, para
# que la página de diagnóstico no tenga que decidir nada:
#
#   :ok       ●  responde
#   :failed   ✕  no responde, y eso es un problema
#   :pending  ○  todavía no aplica en esta fase
#
# Ninguna comprobación levanta: la página tiene que poder pintarse **con el
# entorno roto**, que es justo cuando hace falta. Un fallo se convierte en un
# estado con su mensaje, nunca en un 500.
#
# Es deliberadamente desechable: en F3 la sustituye el dashboard.
class EnvironmentCheck
  Result = Data.define(:label, :status, :detail) do
    def ok? = status == :ok
  end

  def self.all
    new.all
  end

  def all
    [ postgres, redis, sidekiq, active_storage, agent_runtime, contracts ]
  end

  private

  def postgres
    connection = ActiveRecord::Base.connection
    version = connection.select_value("SHOW server_version")

    check("Postgres", detail: "#{connection.current_database} · v#{version}")
  rescue StandardError => e
    failure("Postgres", e)
  end

  def redis
    pong = Sidekiq.redis { |connection| connection.call("PING") }
    raise "respuesta inesperada: #{pong.inspect}" unless pong.to_s.casecmp?("PONG")

    check("Redis", detail: redis_url_without_credentials)
  rescue StandardError => e
    failure("Redis", e)
  end

  # Que Redis responda no significa que haya un worker escuchando. Son dos
  # cosas distintas y se enseñan por separado: sin worker, un job encolado se
  # queda en la cola para siempre y desde la aplicación no se nota.
  def sidekiq
    # `sidekiq/api` no se carga solo. Hasta Sidekiq 8.1.6 llegaba por otro
    # camino y esto funcionaba de rebote; 8.1.7 —el mínimo que exige Rails
    # 8.1— ya no lo trae, y sin el require la pantalla de diagnóstico decía
    # `NameError` justo cuando se la consulta para saber qué está roto.
    require "sidekiq/api"

    processes = Sidekiq::ProcessSet.new
    count = processes.size

    if count.zero?
      Result.new(label: "Sidekiq", status: :failed,
                 detail: "ningún worker vivo · arranca `bundle exec sidekiq`")
    else
      check("Sidekiq", detail: "#{count} #{'worker'.pluralize(count)} · #{processes.total_concurrency} de concurrencia")
    end
  rescue StandardError => e
    failure("Sidekiq", e)
  end

  def active_storage
    service = ActiveStorage::Blob.service.name
    check("Active Storage", detail: "servicio :#{service}")
  rescue StandardError => e
    failure("Active Storage", e)
  end

  # No es una comprobación de salud: es un recordatorio de contra qué se está
  # trabajando. `fake` recorre el pipeline sin llamar a ningún modelo.
  def agent_runtime
    runtime = ENV.fetch("MATRIX_AGENT_RUNTIME", "fake")

    Result.new(
      label: "Runtime de agentes",
      status: runtime == "brain" ? :ok : :pending,
      detail: runtime == "brain" ? "identia-brain" : "#{runtime} · sin llamadas a ningún modelo"
    )
  end

  def contracts
    Contracts.names.each { |name| Contracts.schema(name) }

    check("Contratos", detail: "#{Contracts.names.size} esquemas compilan")
  rescue StandardError => e
    failure("Contratos", e)
  end

  def check(label, detail:)
    Result.new(label: label, status: :ok, detail: detail)
  end

  def failure(label, error)
    Result.new(label: label, status: :failed, detail: "#{error.class}: #{error.message.lines.first&.strip}")
  end

  def redis_url_without_credentials
    uri = URI.parse(ENV.fetch("REDIS_URL", "redis://localhost:6381/0"))
    "#{uri.host}:#{uri.port}#{uri.path}"
  rescue URI::InvalidURIError
    "url no interpretable"
  end
end
