require "test_helper"

# Los tests de sistema tienen que correr en los dos modos sin tocar nada: con el
# Chrome del anfitrión, y con el Chromium que el stage `development` del
# Dockerfile instala en el contenedor.
#
# Selenium encuentra Chrome solo en el anfitrión, pero dentro del contenedor el
# binario se llama `chromium` y no está donde lo busca. Se le dice dónde está
# cuando existe, y se le deja hacer cuando no.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  CONTAINER_CHROME = "/usr/bin/chromium".freeze

  def self.in_container? = File.exist?(CONTAINER_CHROME)

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    if in_container?
      options.binary = CONTAINER_CHROME
      # Sin esto Chrome muere dentro del contenedor: /dev/shm son 64 MB por
      # defecto y no le llegan.
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--no-sandbox")
    end
  end

  include SystemSessionHelpers

  # La suscripción al cable se establece DESPUÉS de cargar la página, y Turbo no
  # reenvía lo que se emitió antes de que existiera: un test que publica nada
  # más cargar pasa o falla según lo rápido que vaya la máquina.
  #
  # Esto emite eventos de prueba hasta que uno llega. Cuando el primero aparece,
  # el canal está vivo y lo que se publique después es determinista.
  def wait_for_turbo_stream(attempts: 10)
    marker = "· cable listo ·"

    attempts.times do
      Event.create!(occurred_at: Time.current, actor: "TEST", kind: "probe",
                    message: marker)
      return true if page.has_text?(marker, wait: 0.5)
    end

    flunk "el canal de Turbo no se suscribió tras #{attempts} intentos"
  ensure
    Event.where(kind: "probe").delete_all
  end
end
