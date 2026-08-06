# El historial. Aquí se decide si el sistema conserva su pasado o lo sobrescribe.
#
# `stage_entries` y `events` no son redundantes: uno es estado estructurado y
# consultable —la tira de doce glifos—, el otro es narrativa —el event stream—.
# La maqueta necesita los dos.
class CreatePipelineHistory < ActiveRecord::Migration[8.0]
  def change
    create_table :stage_entries do |t|
      t.references :initiative, null: false, foreign_key: true
      t.integer :stage, null: false
      # Un retorno INSERTA filas con iteration+1 en vez de sobrescribir. Ese es
      # el mecanismo entero por el que el historial sobrevive.
      t.integer :iteration, null: false, default: 1
      t.integer :status, null: false, default: 0
      # Dato de presentación: es lo que la maqueta pinta como «ciclo 1/2».
      t.integer :qa_cycle, null: false, default: 0

      t.datetime :entered_at
      t.datetime :exited_at
      # El subtítulo y la marca derecha del nodo en la maqueta.
      t.string :summary
      t.string :metric
      t.timestamps

      t.index [ :initiative_id, :stage, :iteration ], unique: true,
              name: "idx_stage_entries_unique_occurrence"
    end

    create_table :agent_runs do |t|
      t.references :initiative, null: false, foreign_key: true
      t.integer :agent, null: false
      # SERAPH interviene dos veces con propósitos distintos: `dod_pass` antes
      # de ejecutar y `verification` después. Sin esa distinción, el índice
      # único de F9 le impediría verificar tras haber escrito el DoD.
      t.integer :purpose, null: false
      t.integer :iteration, null: false, default: 1
      t.integer :qa_cycle, null: false, default: 0
      t.string :code, null: false
      t.integer :status, null: false, default: 0

      t.datetime :started_at
      t.datetime :finished_at
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :cost_cents
      t.string :brain_request_id
      t.text :error
      t.timestamps

      t.index :code, unique: true
      # Una sola ejecución VIVA por etapa. Lo impide la base de datos, no un
      # controlador: la interfaz, un relanzamiento manual y el reintento de un
      # job pueden solaparse.
      t.index [ :initiative_id, :agent, :purpose, :iteration ], unique: true,
              where: "status IN (0, 1)", name: "idx_agent_runs_one_live"
    end

    create_table :events do |t|
      t.datetime :occurred_at, null: false
      t.string :actor, null: false
      # Nullable: no todo evento es de un evolutivo. `SYNC vivla · 14 docs` es
      # del cliente y de nadie más.
      t.references :initiative, foreign_key: true
      t.references :platform_client, foreign_key: true
      t.string :kind, null: false
      t.string :message, null: false
      t.jsonb :payload, null: false, default: {}
      t.timestamps

      t.index :occurred_at
    end

    create_table :escalations do |t|
      # Desnormalizados por lo mismo que en initiatives: la bandeja del
      # dashboard lista escaladas por evolutivo, y la frontera de cliente se
      # comprueba con un `where`.
      t.references :initiative, null: false, foreign_key: true
      t.references :platform_client, null: false, foreign_key: true
      t.integer :reason, null: false

      t.datetime :opened_at, null: false
      # Los tres primeros motivos los abre el sistema. `unwalkable_step` lo abre
      # una PERSONA bloqueada y lo cierra OTRA autorizando: por eso lleva
      # `opened_by_user_id` y `guide_step_id`, que los otros tres no usan.
      t.references :opened_by_user, foreign_key: { to_table: :platform_users }
      t.bigint :opened_by_verification_id
      t.bigint :guide_step_id

      t.datetime :resolved_at
      t.references :resolved_by_user, foreign_key: { to_table: :platform_users }
      t.bigint :human_note_id
      t.timestamps

      t.index [ :initiative_id, :reason ]
      t.index :resolved_at
    end

    create_table :human_notes do |t|
      t.references :initiative, null: false, foreign_key: true
      t.references :platform_client, null: false, foreign_key: true
      t.references :author_user, null: false, foreign_key: { to_table: :platform_users }
      # 2026-05-08-ap · lo que va dentro de [src:note/…]
      t.string :code, null: false
      t.text :body, null: false
      t.timestamps

      t.index :code, unique: true
    end
  end
end
