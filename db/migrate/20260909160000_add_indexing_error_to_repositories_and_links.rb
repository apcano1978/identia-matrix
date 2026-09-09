# Por qué no se pudo leer un repositorio (F12 · B6).
#
# Desde que la indexación se encola sola, el fallo deja de tener a nadie delante
# mirando la salida de una tarea: ocurre en segundo plano, media hora después de
# registrar el repositorio. Si el motivo no se guarda, se pierde — y el síntoma
# vuelve a ser el de P23: `pinned_sha` nulo, TANK sin una línea de código, y
# nada que lo explique.
#
# ── Dos columnas porque son DOS preguntas ──────────────────────────────────
#
# La misma razón por la que `head_sha` y `pinned_sha` son dos columnas:
#
#   repositories.indexing_error            ¿se puede leer este repositorio?
#   initiative_repositories.indexing_error ¿por qué ESTE evolutivo no lo ancló?
#
# No son la misma respuesta. Un repositorio legible puede fallar al anclarlo para
# un evolutivo concreto —un 502 justo entonces— y un repositorio sin `remote_url`
# falla igual para todos. Guardarlo en un solo sitio obligaría a elegir cuál de
# las dos se pierde.
#
# ── Estado derivado de columnas, no de un enum paralelo ────────────────────
#
# Es el patrón que B2 dejó probado con `ProjectDocument` (`extracted_at` +
# `extraction_error`): el estado se lee de los datos que ya hay y no puede
# discrepar de ellos. Aquí los datos son `last_synced_at`/`pinned_sha` para el
# éxito y estas dos para el fallo; la ausencia de ambos es «en cola».
class AddIndexingErrorToRepositoriesAndLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :indexing_error, :string
    add_column :initiative_repositories, :indexing_error, :string
  end
end
