require "sidekiq/web"

Rails.application.routes.draw do
  # Matrix no tiene usuarios propios ni contraseñas: el login va contra los de
  # identia-platform. Por eso hay sesión pero no restablecimiento de contraseña
  # — no se puede restablecer una credencial que no es tuya. Ver F2 §1.7.
  resource :session

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Interfaz de Sidekiq. En producción la protege basic auth por variables de
  # entorno; en desarrollo queda abierta, igual que en identia-platform.
  #
  # OJO: va montada como Rack, fuera de ApplicationController, así que el
  # `require_authentication` del concern de autenticación NO le aplica.
  if Rails.env.production?
    Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, ENV.fetch("SIDEKIQ_USERNAME", "")) &
        ActiveSupport::SecurityUtils.secure_compare(password, ENV.fetch("SIDEKIQ_PASSWORD", ""))
    end
  end
  mount Sidekiq::Web => "/sidekiq"

  # Página de diagnóstico del entorno. SOLO EN LOCAL, y sin autenticar.
  #
  # Sin autenticar a propósito: una pantalla de diagnóstico detrás de un login es
  # inútil justo cuando hace falta. Si Postgres está caído no puedes entrar, y
  # entonces no puedes ver la página que te diría que Postgres está caído.
  #
  # Solo en local para no dejarle una trampa a F3: cuando el dashboard ocupe `/`,
  # no hay ninguna ruta pública que alguien tenga que acordarse de cerrar.
  root "home#show" if Rails.env.local?
end
