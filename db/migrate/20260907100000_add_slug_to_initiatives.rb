# El nombre del evolutivo (F11).
#
# Un evolutivo se llamaba `ev-031` en la URL y dentro de la clave de su artefacto.
# El rediseño lo llama `precio-festivos`, y pide que los códigos desaparezcan de
# donde quepa un nombre.
#
# ── `code` NO se va, y eso no es nostalgia ──────────────────────────────────
#
# Se queda por dos razones duras. El contrato con el brain declara
# `config.initiative.code` con `pattern: "^ev-\d{3,}$"`, obligatorio y con
# `additionalProperties: false`: el slug no cabe ahí hasta que se despliegue el
# otro lado. Y de `code` sale el NÚMERO —`Initiative#number` es
# `code.delete_prefix("ev-")`— del que se componen los códigos de artefacto
# (`ev-031` → `dod-031`); un slug no lleva número.
#
# El evolutivo acaba con las dos: `code` es la identidad interna y hacia el brain,
# `slug` es el nombre hacia fuera.
#
# ── El relleno es `slug = code`, y no una derivación del título ─────────────
#
# `ev-031` ES un slug válido —lo comprobó B1 al ensanchar el patrón de la clave—
# así que copiarlo no rompe nada y ninguna clave emitida cambia. Derivarlo del
# título renombraría los evolutivos que ya existen, y el slug va dentro de claves
# que no se pueden reescribir: en producción, lo que ya está se llamará `ev-NNN`
# para siempre y solo lo nuevo llevará nombre. Es lo correcto.
#
# ── Único por PROYECTO, no global ──────────────────────────────────────────
#
# A diferencia del slug de proyecto. Dos proyectos distintos pueden tener cada uno
# su `rediseno-interfaz`: lo que hace única una clave de artefacto es la pareja
# proyecto + evolutivo, no el evolutivo solo.
class AddSlugToInitiatives < ActiveRecord::Migration[8.1]
  def up
    add_column :initiatives, :slug, :string

    execute "UPDATE initiatives SET slug = code WHERE slug IS NULL"

    change_column_null :initiatives, :slug, false
    add_index :initiatives, [ :project_id, :slug ], unique: true
  end

  def down
    remove_index :initiatives, [ :project_id, :slug ]
    remove_column :initiatives, :slug
  end
end
