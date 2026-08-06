# La fuente real: `GET /internal/v1/...` contra identia-platform, con el
# contrato `matrix-platform/read.v1.json`.
#
# Llega en F8. No finge: un stub que devolviera listas vacías dejaría la
# proyección en blanco sin que nada dijera por qué.
module Platform::HttpSource
  module_function

  def clients = not_yet
  def users = not_yet
  def projects = not_yet
  def documents = not_yet
  def meetings = not_yet

  def name = "platform"

  def not_yet
    raise NotImplementedError,
          "la sincronización con platform llega en F8; " \
          "usa MATRIX_PLATFORM_SOURCE=fake mientras tanto"
  end
end
