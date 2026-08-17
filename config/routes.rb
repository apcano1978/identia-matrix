require "sidekiq/web"

Rails.application.routes.draw do
  # Matrix no tiene usuarios propios ni contraseñas: el login va contra los de
  # identia-platform. Por eso hay sesión pero no restablecimiento de contraseña
  # — no se puede restablecer una credencial que no es tuya. Ver F2 §1.7.
  #
  # `only:` explícito: `resource :session` a secas declara también un `update`
  # que ningún controlador implementa. Una ruta de escritura sin acción detrás
  # es una puerta pintada, y la lista blanca de escrituras la delató.
  resource :session, only: %i[new create destroy]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Interfaz de Sidekiq. En producción la protege basic auth por variables de
  # entorno; en desarrollo queda abierta, igual que en identia-platform.
  #
  # OJO: va montada como Rack, fuera de ApplicationController, así que el
  # `require_authentication` del concern de autenticación NO le aplica.
  if Rails.env.production?
    # ⚠ Con `ENV.fetch(..., "")` de respaldo, unas credenciales SIN PONER
    # comparan "" con "" y **entra cualquiera con usuario y contraseña vacíos**.
    # Era inocuo mientras matrix no tenía producción; deja de serlo el día que
    # se despliega. Se comprueba al arrancar y se cae ruidosamente, que es la
    # única forma de que un secreto que falta no se convierta en una puerta.
    expected_username = ENV["SIDEKIQ_USERNAME"].to_s
    expected_password = ENV["SIDEKIQ_PASSWORD"].to_s

    if expected_username.empty? || expected_password.empty?
      raise "SIDEKIQ_USERNAME y SIDEKIQ_PASSWORD son obligatorias en producción: " \
            "sin ellas /sidekiq queda abierto con credenciales vacías"
    end

    Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, expected_username) &
        ActiveSupport::SecurityUtils.secure_compare(password, expected_password)
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
  # INVARIANTE 8, escrito en la forma de la ruta: ante un conflicto de
  # procedencia gana el ORIGEN, y lo único que se puede crear es la RESOLUCIÓN.
  # No hay `update`, no hay `destroy`, y no existe ningún parámetro que diga a
  # favor de quién. Que no haya forma de resolverlo al revés se lee en
  # `bin/rails routes`, sin abrir el controlador.
  resources :citation_conflicts, only: [] do
    resource :resolution, only: :create,
                          controller: "citation_conflict_resolutions"
  end

  resources :clients, only: %i[index show], param: :slug do
    resources :initiatives, only: :show, param: :code do
      # Lo que un agente puede leer y citar para este evolutivo. Cuelga del
      # evolutivo porque el ámbito documental es suyo; las fuentes, no.
      resources :sources, only: :index
    end
    # Los nombres de repositorio admiten punto —`docs.site`—, y sin la
    # restricción Rails se comería el sufijo tomándolo por un formato.
    resources :repositories, only: :show, param: :name,
                             constraints: { name: %r{[^/]+} }
  end

  resources :agents, only: %i[index show], param: :key

  # El enlace profundo desde identia-platform: `/p/proj-2291` resuelve la
  # referencia de proyecto a sus evolutivos y sus artefactos publicados.
  #
  # Corto a propósito — lo construye platform concatenando una plantilla con la
  # `ref` que ya tiene— y sin API en sentido inverso: hoy basta con atravesar.
  get "/p/:platform_project_ref" => "platform_projects#show",
      as: :platform_project_deep_link,
      constraints: { platform_project_ref: %r{[A-Za-z0-9._-]+} }

  root "dashboard#show"
end
