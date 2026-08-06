source "https://rubygems.org"

gem "rails", "~> 8.0.4"
# Pipeline de assets moderno [https://github.com/rails/propshaft]
gem "propshaft"
# Postgres como base de datos de Active Record
gem "pg", "~> 1.1"
# Servidor web [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# JavaScript con import maps, sin Node [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire
gem "turbo-rails"
gem "stimulus-rails"
# Tailwind 4 vía binario standalone: sin Node, sin package.json.
# La configuración es CSS-first, en app/assets/tailwind/application.css.
gem "tailwindcss-rails"
gem "jbuilder"

# Windows no trae zoneinfo
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Acelera el arranque cacheando; requerido en config/boot.rb
gem "bootsnap", require: false

# Caché HTTP de assets y X-Sendfile sobre Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# --- Dominio de matrix -------------------------------------------------------

# Autorización. Misma convención que identia-platform: policies finas colgando
# de predicados de User, más Scope para el filtrado de índices.
gem "pundit", "~> 2.5"

# Trabajo en segundo plano. Las ejecuciones de agente son lentas (minutos) y
# nunca deben ocurrir en el ciclo de petición.
gem "sidekiq", "~> 8.0"
gem "sidekiq-cron", "~> 2.0"
gem "redis", "~> 5.3"

# Cliente HTTP contra identia-brain (agentes) e identia-platform (proyección).
gem "faraday", "~> 2.9"

# Validación de los contratos JSON Schema de contracts/. Soporta draft 2020-12,
# que es el que declaran nuestros esquemas.
gem "json_schemer", "~> 2.3"

# Render del markdown de los artefactos (spec, DoD, guía, cierre).
gem "commonmarker", "~> 2.0"

# Paginación de listados largos.
gem "pagy", "~> 43.6"

# Contraseñas de usuario (has_secure_password).

# Active Storage sobre S3: el bucket de artefactos en producción (F4).
# En desarrollo y test el servicio es :local.
gem "aws-sdk-s3", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Análisis estático de seguridad [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Estilo omakase [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Fijado a 5.x a propósito: minitest 6 eliminó minitest/mock (Object#stub),
  # que usan los tests de runtime de agente. Mismo pin que identia-platform.
  gem "minitest", "~> 5.25"
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
