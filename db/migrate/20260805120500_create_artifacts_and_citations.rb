# Artefactos, citas y fuentes: lo que hace auditable el trabajo de los agentes.
#
# Un artefacto es inmutable y su clave también. Una cita resuelve SIEMPRE contra
# la fuente, nunca contra un índice — así, el día que el índice se rehaga en
# brain, ninguna cita ya emitida se rompe.
class CreateArtifactsAndCitations < ActiveRecord::Migration[8.0]
  def change
    create_table :artifacts do |t|
      t.references :initiative, null: false, foreign_key: true
      t.references :platform_client, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :code, null: false
      t.integer :version, null: false, default: 1
      # artifacts://vivla/ev-031/dod-031/v2.md — congelada en F0.
      t.string :storage_key, null: false
      t.string :checksum, null: false
      t.jsonb :front_matter, null: false, default: {}
      t.references :produced_by_run, foreign_key: { to_table: :agent_runs }
      t.timestamps

      # Sin update y sin destroy en el modelo. Esto solo impide el duplicado.
      t.index :storage_key, unique: true
      t.index [ :initiative_id, :code, :version ], unique: true
    end

    create_table :citations do |t|
      t.references :citable, polymorphic: true, null: false
      t.string :raw, null: false
      # code doc meet note spec dod verify pkg close — nueve tipos.
      # El NIVEL no se almacena: se deriva con Citations::Grammar.level, porque
      # un dato derivable que se guarda es un dato que se desincroniza.
      t.integer :source_kind, null: false
      # Obligatorio cuando source_kind es `code` o `verify`. Es el invariante 4
      # en el modelo: ninguna afirmación sobre el código sin repositorio.
      t.references :repository, foreign_key: true
      t.string :locator, null: false
      t.string :fragment
      t.string :commit_sha
      # La fuente ya resuelta: Repository, Platform::Document, HumanNote…
      t.references :target, polymorphic: true
      t.integer :position
      t.timestamps

      t.index [ :citable_type, :citable_id, :position ]
      t.index :source_kind
    end

    create_table :citation_conflicts do |t|
      t.references :derived_citation, null: false, foreign_key: { to_table: :citations }
      t.references :origin_citation, null: false, foreign_key: { to_table: :citations }
      t.datetime :detected_at, null: false
      # Gana el ORIGEN. Siempre. No hay forma de resolverlo al revés: no es una
      # decisión que el sistema ofrezca.
      t.string :resolution
      # El artefacto queda marcado para revisión DERIVANDO de aquí, no con una
      # columna suya: la fila de un artefacto no se toca ni para metadatos.
      t.references :flagged_artifact, foreign_key: { to_table: :artifacts }
      t.timestamps
    end

    create_table :initiative_sources do |t|
      t.references :initiative, null: false, foreign_key: true
      # Platform::Document o Platform::Meeting.
      t.references :source, polymorphic: true, null: false
      t.integer :refs_count, null: false, default: 0
      t.timestamps

      # Es un FILTRO, no una copia: su ausencia significa «heredada del
      # cliente», que es lo visible por defecto. Un documento sirve a varios
      # evolutivos sin duplicarse.
      t.index [ :initiative_id, :source_type, :source_id ], unique: true,
              name: "idx_initiative_sources_unique"
    end

    create_table :agent_configs do |t|
      t.integer :agent, null: false
      # Nulo = configuración global. La efectiva es global.deep_merge(override).
      t.references :platform_client, foreign_key: true
      t.jsonb :settings, null: false, default: {}
      t.references :updated_by_user, foreign_key: { to_table: :platform_users }
      t.timestamps

      t.index [ :agent, :platform_client_id ], unique: true
    end

    create_table :adrs do |t|
      t.references :repository, null: false, foreign_key: true
      t.string :code, null: false
      t.string :title, null: false
      t.references :origin_initiative, foreign_key: { to_table: :initiatives }
      # current · disputed
      t.integer :status, null: false, default: 0
      t.timestamps

      t.index [ :repository_id, :code ], unique: true
    end

    add_foreign_key :definitions_of_done, :artifacts, column: :artifact_id
    add_foreign_key :definitions_of_done, :artifacts, column: :derived_from_artifact_id
    add_foreign_key :verification_reports, :artifacts, column: :artifact_id
    add_foreign_key :work_packages, :artifacts, column: :artifact_id
    add_foreign_key :test_guides, :artifacts, column: :artifact_id
    add_foreign_key :dod_criteria, :citations, column: :trace_citation_id
    add_foreign_key :verdicts, :citations, column: :evidence_citation_id
  end
end
