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
  # Vive en `/diagnostics` y no en `/up`: el healthcheck que mira kamal-proxy
  # tiene que ser un 200 barato. Uno que consulte Redis y Sidekiq tumba un
  # despliegue cuando Redis parpadea, y deja de responder justo cuando hace falta.
  get "diagnostics" => "diagnostics#show" if Rails.env.local?

  # El eje de trabajo cuelga del cliente, y el de memoria también. Las rutas lo
  # dicen: no hay ningún evolutivo ni ningún repositorio fuera de su cliente, que
  # es la frontera dura del sistema.
  resources :clients, only: %i[index show], param: :slug do
    resources :initiatives, only: :show, param: :code
    # Los nombres de repositorio admiten punto —`docs.site`—, y sin la
    # restricción Rails se comería el sufijo tomándolo por un formato.
    resources :repositories, only: :show, param: :name,
                             constraints: { name: %r{[^/]+} }
  end

  resources :agents, only: %i[index show], param: :key

  root "dashboard#show"
end
