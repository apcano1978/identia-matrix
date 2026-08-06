require "sidekiq"

# Redis de matrix. En desarrollo el contenedor publica en 6381 para no chocar
# con identia-platform (6380) ni con un Redis local de Homebrew (6379).
redis_config = { url: ENV.fetch("REDIS_URL", "redis://localhost:6381/0") }

Sidekiq.configure_server do |config|
  config.redis = redis_config

  # Carga las tareas periódicas (sidekiq-cron) al arrancar el worker.
  #
  # OJO con el fichero vacío: `config/schedule.yml` hoy solo tiene comentarios,
  # y `YAML.load_file` sobre eso devuelve `nil`. Pasarle `nil` a
  # `load_from_hash!` levanta «Not supported schedule format» **en el evento de
  # arranque**, y el worker muere sin llegar a coger un solo job.
  #
  # Por eso no basta con comprobar que el fichero existe: hay que comprobar que
  # trae algo.
  config.on(:startup) do
    schedule_file = Rails.root.join("config", "schedule.yml")
    schedule = File.exist?(schedule_file) ? YAML.load_file(schedule_file) : nil

    if schedule.is_a?(Hash) && schedule.any?
      require "sidekiq/cron"
      Sidekiq::Cron::Job.load_from_hash!(schedule)
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
