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
end
