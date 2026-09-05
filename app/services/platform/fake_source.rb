# La fuente falsa de la proyección: devuelve los datos de la maqueta con la
# MISMA forma que devolverá `Platform::HttpSource` en F8.
#
# Cinco métodos, uno por tabla proyectada, cada uno una lista de hashes con las
# claves de la tabla. Esa es toda la interfaz: quien importa no sabe si detrás
# hay un fichero o una llamada HTTP, y por eso F8 solo tiene que escribir la
# otra fuente.
module Platform::FakeSource
  module_function

  # **Una divergencia deliberada con la fuente real.** `HttpSource#clients` solo
  # devuelve los leads con proyecto activo; aquí salen los seis del catálogo,
  # tengan proyecto o no. Son el material con el que se miran las pantallas en
  # local, y recortarlos dejaría medio seed sin usar.
  def clients = DesignSeed::Catalog::CLIENTS
  def users = DesignSeed::Catalog::USERS
  def projects = DesignSeed::Catalog::PROJECTS
  def documents = DesignSeed::Catalog::DOCUMENTS
  def meetings = DesignSeed::Catalog::MEETINGS

  def name = "fake"
end
