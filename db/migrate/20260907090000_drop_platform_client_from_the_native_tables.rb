# La frontera se muda de cliente a proyecto: segunda mitad, y la irreversible (F11).
#
# Este es el paso de CONTRAER. Desde aquí ya no hay dos verdades sobre a quién
# pertenece el trabajo de matrix: la respuesta es el proyecto, y no queda columna
# con la que discrepar.
#
# El andamio que sostenía el tramo del medio —el test que comprobaba que las dos
# columnas decían lo mismo— se borra con este commit: comparar una columna
# consigo misma no afirma nada.
#
# ── Lo que NO se retira, y por qué ──────────────────────────────────────────
#
# `events` conserva las dos. Es la única, y es deliberado: «SYNC vivla · 14 docs»
# es un hecho DEL CLIENTE —ocurre antes de que exista ningún proyecto, y no
# tendría a cuál apuntar— mientras que «ev-031 avanza a NEO» es del proyecto. Un
# evento tiene legítimamente dos fronteras, y los eventos no son material de
# agente: `Runtime::Request` no los envía nunca, así que el invariante 10 no
# obliga a mudarlos.
#
# `projects` la lleva porque es suya, y las tres tablas de proyección
# —`platform_documents`, `platform_meetings`, `platform_projects`— porque llegan
# de platform sin ninguna noción de proyecto de matrix.
class DropPlatformClientFromTheNativeTables < ActiveRecord::Migration[8.1]
  # Las siete que pierden la columna. `events` no está.
  TABLES = %i[
    agent_configs artifacts escalations human_notes
    initiatives repositories repository_credentials
  ].freeze

  # Las seis donde el proyecto pasa a ser obligatorio. `agent_configs` no está:
  # su nulo significa «configuración global» y tiene que poder seguir siéndolo.
  REQUIRED = %i[
    artifacts escalations human_notes initiatives repositories repository_credentials
  ].freeze

  def up
    # 1 · El backfill de la expansión, otra vez.
    #
    # Con las dos migraciones en el mismo despliegue no hay hueco. Pero si la de
    # expandir llegó a producción en un despliegue anterior, entre las dos pudo
    # aparecer un cliente con trabajo — y entonces el `null: false` de abajo
    # abortaría a mitad de la migración. Es barato y evita esa clase de tarde.
    execute <<~SQL.squish
      INSERT INTO projects (slug, name, platform_client_id, opened_at, created_at, updated_at)
      SELECT c.slug, c.name, c.id, NOW(), NOW(), NOW()
        FROM platform_clients c
       WHERE NOT EXISTS (SELECT 1 FROM projects p WHERE p.platform_client_id = c.id)
    SQL

    TABLES.each do |table|
      next unless column_exists?(table, :platform_client_id)

      execute <<~SQL.squish
        UPDATE #{table} t SET project_id = p.id
          FROM projects p
         WHERE p.platform_client_id = t.platform_client_id
           AND t.platform_client_id IS NOT NULL
           AND t.project_id IS NULL
      SQL
    end

    REQUIRED.each { |table| change_column_null table, :project_id, false }

    # 2 · Los cinco índices compuestos, que `remove_reference` no recrea solo.
    #
    # ⚠ El de `agent_configs` NO protege la fila global: Postgres no hace
    # colisionar NULL en un índice único, así que dos globales del mismo agente
    # cabrían. Quien lo impide es la validación de Rails, que sí trata el nulo
    # como valor. Era igual antes de F11 — se anota para que nadie lea el índice
    # y crea que basta.
    add_index :repositories, [ :project_id, :name ], unique: true
    add_index :human_notes, [ :project_id, :code ], unique: true
    add_index :agent_configs, [ :agent, :project_id ], unique: true
    add_index :initiatives, [ :project_id, :current_stage ]
    # Conserva el nombre: es el que nombra el comentario de `current_for`.
    add_index :repository_credentials, [ :project_id, :host, :created_at ],
              name: "idx_repository_credentials_latest_by_project"

    # 3 · Y fuera la columna, con su clave foránea y sus índices viejos.
    TABLES.each { |table| remove_reference table, :platform_client, foreign_key: true }
  end

  # IRREVERSIBLE, y se declara en vez de fingir un `down` a medias.
  #
  # Devolver la columna es fácil; devolver el DATO no siempre: un proyecto propio
  # no tiene cliente al que volver, así que la vuelta exigiría decidir qué
  # inventarse para sus filas. Un `down` que hace media cosa es peor que ninguno,
  # porque invita a ejecutarlo.
  #
  # Para deshacer esto de verdad: revertir el commit y restaurar desde copia.
  def down
    raise ActiveRecord::IrreversibleMigration,
          "un proyecto propio no tiene cliente al que volver: revierte el commit " \
          "y restaura desde copia"
  end
end
