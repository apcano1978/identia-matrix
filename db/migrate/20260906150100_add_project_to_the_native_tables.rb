# La frontera se muda de cliente a proyecto: primera mitad (F11).
#
# Este es el paso de EXPANDIR de un expandir → migrar → contraer. Las dos
# columnas conviven a propósito, y no por prudencia con el despliegue —kamal es
# atómico— sino por la SUITE: treinta ficheros de test hablan de
# `platform_client`, y con las dos vivas se puede mover primero a quien LEE
# (`Citations::Resolve`, `Runtime::Request`, `Sources::Scope`) sin tocar todavía a
# quien escribe, y afirmar por el camino que las dos columnas coinciden fila a
# fila. Esa red no existiría haciéndolo de golpe. Se retira al contraer.
#
# Ocho tablas, que son las NATIVAS de matrix. Las tres de proyección
# —`platform_documents`, `platform_meetings`, `platform_projects`— no se tocan:
# llegan de platform sin ninguna noción de proyecto de matrix, y un documento
# puede alimentar legítimamente a dos proyectos del mismo cliente. Eso no es
# «material de otro proyecto»: es material del cliente, y su acotado lo hace
# `initiative_sources`, no una clave foránea.
#
# **`events` conserva las dos columnas para siempre**, y es la única. «SYNC vivla
# · 14 docs» es un hecho DEL CLIENTE: ocurre antes de que exista ningún proyecto,
# y no tendría a cuál apuntar. Y los eventos no son material de agente
# —`Runtime::Request` no los envía nunca— así que el invariante 10 no obliga a
# mudarlos. La ficha de proyecto filtrará por `project_id`; la de cliente, por
# `platform_client_id`.
#
# El relleno va en SQL CRUDO y no por ActiveRecord, y no es preferencia:
# `Artifact` cierra la inmutabilidad con `before_update`, `before_destroy` y
# `before_save`, así que un `update` por AR moriría en la primera de las setenta
# filas. Las tablas `platform_*` tienen la misma protección por otro camino
# (`Platform::Record#readonly?`).
class AddProjectToTheNativeTables < ActiveRecord::Migration[8.1]
  # Las ocho nativas. `agent_configs` y `events` admiten nulo por razones
  # distintas y las dos legítimas: en la primera, nulo significa «configuración
  # global»; en la segunda, «hecho del sistema o del cliente».
  TABLES = %i[
    agent_configs artifacts escalations events
    human_notes initiatives repositories repository_credentials
  ].freeze

  def up
    TABLES.each do |table|
      add_reference table, :project, null: true, foreign_key: true
    end

    TABLES.each do |table|
      # Solo las filas que hoy cuelgan de un cliente. Donde el cliente es nulo,
      # el nulo SIGNIFICA algo y convertirlo en un proyecto sería inventarse un
      # dato que nadie escribió.
      execute <<~SQL.squish
        UPDATE #{table} t
           SET project_id = p.id
          FROM projects p
         WHERE p.platform_client_id = t.platform_client_id
           AND t.platform_client_id IS NOT NULL
      SQL
    end
  end

  def down
    TABLES.each { |table| remove_reference table, :project, foreign_key: true }
  end
end
