# El paquete de trabajo, la guía de pruebas y las dos puertas.
#
# GATE 1 autoriza a ejecutar y es irreversible. GATE 2 confirma que lo ejecutado
# sirve y es reversible por rechazo. Esa asimetría está en el modelo, no solo en
# la interfaz.
class CreatePackagesAndGates < ActiveRecord::Migration[8.0]
  def change
    create_table :work_packages do |t|
      t.references :initiative, null: false, foreign_key: true
      t.string :code, null: false
      t.references :agent_run, foreign_key: true
      t.integer :tasks_count, null: false, default: 0
      t.integer :new_files_count, null: false, default: 0
      t.integer :modified_files_count, null: false, default: 0
      t.integer :migrations_count, null: false, default: 0
      t.datetime :sealed_at
      t.string :content_hash
      t.bigint :artifact_id
      t.timestamps

      t.index :code, unique: true
    end

    create_table :work_package_repositories do |t|
      t.references :work_package, null: false, foreign_key: true
      t.references :repository, null: false, foreign_key: true
      # El orden importa: durante la ventana convive una versión nueva con una
      # vieja. Un paquete multi-repo SIN estas filas está incompleto y MORFEO
      # lo marca bloqueante.
      t.integer :deploy_order, null: false
      t.string :write_scope
      t.text :compatibility_note
      t.timestamps

      t.index [ :work_package_id, :repository_id ], unique: true
      t.index [ :work_package_id, :deploy_order ], unique: true
    end

    create_table :gate_signatures do |t|
      t.references :initiative, null: false, foreign_key: true
      # Una firma por paquete: el índice va en la propia referencia para no
      # duplicar el que `t.references` ya crea.
      t.references :work_package, null: false, foreign_key: true, index: { unique: true }
      t.string :package_hash, null: false
      t.references :signed_by_user, null: false, foreign_key: { to_table: :platform_users }
      # La identidad CONGELADA en el momento de firmar. No es redundante con
      # signed_by_user_id: el usuario es una proyección de platform que puede
      # cambiar de nombre, de rol o desaparecer. Sin esta copia, el registro de
      # una firma irreversible podría dejar de decir quién firmó.
      t.string :identity, null: false
      t.datetime :signed_at, null: false
      # En primera persona y específica del paquete: lo que se firma es una
      # afirmación concreta, no un «acepto» genérico. La compone el sistema.
      t.text :statement, null: false
      t.timestamps
    end

    create_table :gate_signature_commits do |t|
      t.references :gate_signature, null: false, foreign_key: true
      t.references :repository, null: false, foreign_key: true
      # SELLADO al firmar, copiado del paquete: la firma es autosuficiente
      # aunque el paquete se vuelva a sellar más tarde. Invariante 9.
      t.string :base_sha, null: false
      t.string :write_scope
      t.integer :deploy_order, null: false
      # EJECUTADO, y por eso nullable: se conoce después, cuando Claude Code
      # termina. Son dos sha distintos por par (evolutivo, repositorio) y
      # colapsarlos perdería la única forma de saber sobre qué se firmó y sobre
      # qué se verificó.
      t.string :executed_sha
      t.references :executed_confirmed_by, foreign_key: { to_table: :platform_users }
      t.datetime :executed_confirmed_at
      t.timestamps

      t.index [ :gate_signature_id, :repository_id ], unique: true
    end

    create_table :test_guides do |t|
      t.references :initiative, null: false, foreign_key: true
      t.string :code, null: false
      # Solo existe si el informe dio conforme: un evolutivo no puede estar a la
      # vez devuelto a NEO y esperando validación. Invariante 11.
      t.references :verification_report, null: false, foreign_key: true
      t.bigint :artifact_id
      t.timestamps

      t.index :code, unique: true
    end

    create_table :guide_steps do |t|
      t.references :test_guide, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :title, null: false
      t.text :body
      # auto_verified · sole_evidence
      t.integer :evidence_origin, null: false
      t.references :dod_criterion, foreign_key: true

      t.datetime :walked_at
      t.references :walked_by_user, foreign_key: { to_table: :platform_users }
      t.text :walk_note

      # EXIMIDO no es RECORRIDO, y se guarda distinto. Un paso eximido es el que
      # un aprobador autorizó cerrar porque nadie podía recorrerlo. Meterlo en
      # «recorrido» haría que la cobertura dijera «4 de 4 recorridos» cuando dos
      # no lo están, y LINK no podría narrarlo como desvío.
      t.datetime :exempted_at
      t.references :exempted_by_user, foreign_key: { to_table: :platform_users }
      t.references :escalation, foreign_key: true
      t.timestamps

      t.index [ :test_guide_id, :position ], unique: true
    end

    create_table :gate_validations do |t|
      t.references :initiative, null: false, foreign_key: true
      t.references :test_guide, null: false, foreign_key: true
      t.integer :decision, null: false
      t.references :decided_by_user, null: false, foreign_key: { to_table: :platform_users }
      t.datetime :decided_at, null: false
      # Congelado en el momento de decidir: es lo que la persona vio delante.
      t.jsonb :coverage_snapshot, null: false, default: {}
      t.text :rejection_note
      t.timestamps

      # SIN índice único: GATE 2 es reversible, y un evolutivo puede acumular
      # varias validaciones si hubo rechazos. Es su diferencia con GATE 1.
      t.index [ :initiative_id, :decided_at ]
    end

    add_foreign_key :escalations, :guide_steps, column: :guide_step_id
    add_foreign_key :escalations, :human_notes, column: :human_note_id
    add_foreign_key :escalations, :verification_reports, column: :opened_by_verification_id
    add_foreign_key :verdicts, :guide_steps, column: :guide_step_id
  end
end
