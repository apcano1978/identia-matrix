# El contador de los códigos que asigna matrix.
#
# Vive en una tabla y no se deriva de `max(code)` porque **un número no se
# recicla nunca**: `ev-031` está dentro de claves de artefacto inmutables y de
# citas ya emitidas. Un contador que sobrevive a las filas es la única forma de
# garantizarlo; un `max` sobre la tabla reparte otra vez el número de lo que se
# borró.
class MatrixSequence < ApplicationRecord
  # Las secuencias que existen. `pkg` la estrenará TRINITY en F9 —hoy el número
  # del paquete sale del catálogo del seed, que es el pendiente P6—; se declara
  # ya porque el mecanismo es el mismo y así no se inventa dos veces.
  INITIATIVE = "initiative"
  PACKAGE    = "package"

  validates :name, presence: true, uniqueness: true
  validates :last_number, numericality: { greater_than_or_equal_to: 0 }
end
