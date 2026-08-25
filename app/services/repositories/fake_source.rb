# La fuente falsa de código: devuelve algo estable sin salir a la red.
#
# No inventa un repositorio: sirve lo que el seed ya puso en la ficha
# —`head_sha` y `files_count`—, de modo que indexar en desarrollo deja la
# pantalla como la maqueta la enseña, y sin credenciales.
#
# **Un `head_sha` que no cambia es lo correcto aquí**: el anclaje existe para
# fijar un estado del código, y una fuente falsa que devolviera un sha distinto
# cada vez haría que el test de «el commit fijado no se mueve» pasara por
# casualidad.
class Repositories::FakeSource
  DEFAULT_SHA = "0000000"

  def initialize(repository) = @repository = repository

  def name = "fake"

  def head_sha(_branch = nil) = @repository.head_sha.presence || DEFAULT_SHA

  def files_count(_sha) = @repository.files_count || 0

  # El cuerpo de un fichero. En falso no hay ficheros de verdad, y devolver una
  # cadena inventada sería peor que decir que no hay: una cita de código que
  # resuelve contra texto falso es exactamente lo que el invariante 4 impide.
  def file(_path, _sha) = nil
end
