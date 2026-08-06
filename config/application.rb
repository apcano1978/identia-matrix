require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module IdentiaMatrix
  class Application < Rails::Application
    config.load_defaults 8.0

    # `runtime/fixtures` y no `fixtures`: la lista se resuelve contra `lib/`, así
    # que "fixtures" habría ignorado un `lib/fixtures` que no existe y el
    # markdown de los agentes habría seguido pasando por Zeitwerk.
    config.autoload_lib(ignore: %w[assets tasks runtime/fixtures])

    # Locale defaults to Spanish (Spain), like identia-platform.
    config.i18n.default_locale = :es
    config.i18n.available_locales = [ :es ]

    config.time_zone = "Madrid"

    # Active Storage: serve blobs through the Rails proxy with signed URLs.
    # Artifacts are the only thing matrix writes, and the bucket must never be
    # reachable directly: access stays under Pundit policies.
    config.active_storage.resolve_model_to_route = :rails_storage_proxy

    # Agent runs take minutes. Nothing that calls an agent may run inside a
    # request, so Active Job goes to Sidekiq everywhere.
    config.active_job.queue_adapter = :sidekiq
  end
end
