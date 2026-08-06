# Los dos ejes del sistema, que NO son padre e hijo.
#
#   Repository  el eje de memoria: acumula los evolutivos que lo han tocado.
#               Sin pipeline y sin estado.
#   Initiative  el eje de trabajo: recorre las doce etapas.
#
# Se cruzan en `initiative_repositories`, que es la matriz evolutivo ×
# repositorio de la ficha de cliente. Ambos cuelgan del cliente.
class CreateAxes < ActiveRecord::Migration[8.0]
  def change
    create_table :repositories do |t|
      # Desnormalizado a propósito: la frontera de cliente se comprueba con un
      # `where`, no navegando asociaciones. Es obligación contractual y tiene
      # que ser barata de imponer en cada consulta.
      t.references :platform_client, null: false, foreign_key: true
      t.string :name, null: false
      t.string :default_branch, null: false, default: "main"
      t.string :head_sha
      t.integer :files_count
      t.string :remote_url
      # Lo que SERAPH consulta en F10. Nulo significa «este repositorio no
      # admite verificación automática», y así se dice en su ficha en vez de
      # fingir que verifica.
      t.string :ci_provider
      t.string :ci_repo_slug
      t.datetime :last_synced_at
      t.timestamps

      t.index [ :platform_client_id, :name ], unique: true
    end

    create_table :initiatives do |t|
      t.references :platform_client, null: false, foreign_key: true
      t.references :platform_project, foreign_key: true
      t.string :code, null: false
      t.string :title, null: false

      # CACHÉ recomputable, no fuente de verdad: la fuente son las
      # stage_entries. Existe por dos razones — el dashboard filtra por estado
      # en SQL, y con una sola etapa actual el invariante 11 deja de ser una
      # regla que vigilar y pasa a ser imposible.
      t.integer :current_stage, null: false, default: 0
      t.integer :current_stage_status, null: false, default: 0

      # Los DOS contadores. `iteration` sube en cualquier salto hacia atrás;
      # `qa_cycles_consumed` solo con un ✕, y con tope 2. Sin el primero, la
      # segunda vuelta por NEO chocaría contra el índice único de stage_entries.
      t.integer :iteration, null: false, default: 1
      t.integer :qa_cycles_consumed, null: false, default: 0

      t.datetime :opened_at, null: false
      t.datetime :stage_changed_at
      t.timestamps

      t.index :code, unique: true
      t.index [ :platform_client_id, :current_stage ]
    end

    create_table :initiative_repositories do |t|
      t.references :initiative, null: false, foreign_key: true
      t.references :repository, null: false, foreign_key: true
      # El commit al que TANK ancló su lectura. Todo lo que cite de este
      # repositorio en este evolutivo habla de este estado del código.
      t.string :pinned_sha
      t.integer :indexed_files_count
      t.datetime :indexed_at
      t.datetime :first_linked_at
      t.timestamps

      t.index [ :initiative_id, :repository_id ], unique: true
    end
  end
end
