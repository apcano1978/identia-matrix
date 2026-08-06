# La proyección cacheada de identia-platform: cinco tablas de SOLO LECTURA.
#
# Matrix nunca crea, edita ni borra un cliente, un proyecto, un documento, una
# transcripción ni un usuario. Solo las escribe la sincronización, y ni siquiera
# ella puede borrarlas: lo que desaparece del origen se marca con
# `missing_since`, porque una cita ya emitida tiene que seguir resolviendo
# dentro de un artefacto que nadie puede reescribir.
#
# `sessions` deja de apuntar a un `users` propio: matrix no tiene usuarios ni
# contraseñas. El login va contra los de platform. Ver F2 §1.7.
class CreatePlatformProjection < ActiveRecord::Migration[8.0]
  def change
    # La sesión sí es de matrix — su duración, su cookie — aunque el usuario no
    # lo sea. Se recrea porque cambia a quién apunta.
    drop_table :sessions
    drop_table :users

    create_table :platform_users do |t|
      t.bigint :platform_id, null: false
      t.string :email_address, null: false
      t.string :name, null: false, default: ""
      # Los tres roles de platform. Matrix solo deja entrar a los dos primeros;
      # esa política es de matrix y no se codifica aquí.
      t.integer :role, null: false, default: 0
      t.string :cargo
      t.boolean :disabled, null: false, default: false

      t.datetime :synced_at
      t.string :sync_source
      t.datetime :missing_since
      t.timestamps

      t.index :platform_id, unique: true
      t.index :email_address, unique: true
      t.index :missing_since
    end

    create_table :platform_clients do |t|
      t.bigint :platform_id, null: false
      # CONGELADO en la primera sincronización: es el segmento de cliente de las
      # claves de artefacto, que son inmutables. El `name` sí se refresca.
      t.string :slug, null: false
      t.string :name, null: false
      t.string :sector
      t.string :city
      t.string :status
      # Solo el cargo, nunca el nombre: la regla de cero PII de platform se
      # queda intacta. Decisión de F7 §5.
      t.string :primary_contact_role
      t.boolean :archived, null: false, default: false

      t.datetime :synced_at
      t.string :sync_source
      t.datetime :missing_since
      t.timestamps

      t.index :platform_id, unique: true
      t.index :slug, unique: true
    end

    create_table :platform_projects do |t|
      t.bigint :platform_id, null: false
      # PRJ-2026-9001. La referencia de negocio de platform, no un id nuestro.
      t.string :platform_project_ref, null: false
      t.string :name, null: false
      t.references :platform_client, null: false, foreign_key: true
      t.string :status
      t.string :current_phase
      t.date :started_on
      t.date :estimated_end_on
      t.boolean :archived, null: false, default: false

      t.datetime :synced_at
      t.string :sync_source
      t.datetime :missing_since
      t.timestamps

      t.index :platform_id, unique: true
      t.index :platform_project_ref, unique: true
    end

    create_table :platform_documents do |t|
      t.bigint :platform_id, null: false
      # CONGELADO: va dentro de las citas [src:doc/acta-precios#p2].
      t.string :slug, null: false
      t.string :title, null: false
      t.references :platform_client, null: false, foreign_key: true
      t.references :platform_project, foreign_key: true
      # Nullable a propósito: en platform el cuerpo no está en tabla, vive en
      # content_versions y en adjuntos. Un PDF sin texto extraído es un caso
      # real, no un error.
      t.text :body
      t.datetime :source_updated_at

      t.datetime :synced_at
      t.string :sync_source
      t.datetime :missing_since
      t.timestamps

      t.index :platform_id, unique: true
      t.index :slug, unique: true
    end

    create_table :platform_meetings do |t|
      t.bigint :platform_id, null: false
      # CONGELADO: es el sufijo opcional de [src:meet/2026-05-02-slug].
      t.string :slug, null: false
      t.string :title, null: false
      t.date :held_on, null: false
      t.references :platform_client, null: false, foreign_key: true
      t.references :platform_project, foreign_key: true
      t.text :body
      t.integer :duration_seconds
      t.datetime :source_updated_at

      t.datetime :synced_at
      t.string :sync_source
      t.datetime :missing_since
      t.timestamps

      t.index :platform_id, unique: true
      t.index :slug, unique: true
      # Las citas de reunión resuelven por fecha; el sufijo desempata.
      t.index :held_on
    end

    create_table :sessions do |t|
      t.references :platform_user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
  end
end
