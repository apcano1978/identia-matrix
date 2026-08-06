# El DoD y su verificación: el contrato contra el que se dictamina, y el
# dictamen. Aquí viven los cuatro veredictos, que son la pieza que distingue a
# este sistema de un gestor de tareas.
class CreateDodAndVerification < ActiveRecord::Migration[8.0]
  def change
    create_table :definitions_of_done do |t|
      t.references :initiative, null: false, foreign_key: true
      t.string :code, null: false
      t.integer :version, null: false, default: 1
      t.references :authored_by_run, foreign_key: { to_table: :agent_runs }
      t.bigint :derived_from_artifact_id
      # Invariante 5: ninguna spec pasa a plan sin revisión de MORFEO. Sin esto
      # relleno, Pipeline::Advance a `trinity` falla.
      t.references :reviewed_by_run, foreign_key: { to_table: :agent_runs }
      t.bigint :artifact_id
      t.timestamps

      t.index [ :initiative_id, :code, :version ], unique: true
    end

    create_table :dod_criteria do |t|
      t.references :definition_of_done, null: false, foreign_key: true
      t.string :key, null: false
      t.text :statement, null: false
      # nil, o `multi_repo_compatibility` para el c0: el criterio obligatorio y
      # automático de todo evolutivo que toque más de un repositorio.
      t.integer :mandatory_kind
      # NULO SIGNIFICA ALGO: «entre servicios». Son los criterios que nada puede
      # verificar dentro de un solo repositorio, y por tanto los que acaban ⊗.
      t.references :repository, foreign_key: true
      t.bigint :trace_citation_id
      # El test que resuelve este criterio. LO NORMAL ES NO TENERLO: la mayor
      # parte de la comprobación es humana por diseño. Sin él, el criterio es ⊗.
      t.string :test_ref
      # Decide si el paso de guía que lo cubre bloquea GATE 2. Se declara al
      # escribir el contrato y lo revisa MORFEO, no se decide al verificar —
      # que es lo que impide ajustarlo a conveniencia cuando hay prisa.
      t.boolean :critical, null: false, default: false
      t.timestamps

      t.index [ :definition_of_done_id, :key ], unique: true
    end

    create_table :verification_reports do |t|
      t.references :initiative, null: false, foreign_key: true
      t.references :definition_of_done, null: false, foreign_key: true
      t.string :code, null: false
      t.references :agent_run, foreign_key: true
      t.integer :iteration, null: false, default: 1
      t.integer :qa_cycle, null: false, default: 0
      t.integer :outcome, null: false, default: 0
      t.bigint :artifact_id
      t.timestamps

      t.index :code, unique: true
    end

    create_table :verdicts do |t|
      t.references :verification_report, null: false, foreign_key: true
      t.references :dod_criterion, null: false, foreign_key: true
      # met · unmet · inconclusive · unsupported → ✓ ✕ ? ⊗
      #
      # SOLO `unmet` consume ciclo de QA. Confundir `inconclusive` o
      # `unsupported` con `unmet` haría que NEO escriba specs para arreglar
      # bugs que no existen: el error más caro que el sistema puede cometer.
      t.integer :result, null: false
      t.text :evidence
      t.bigint :evidence_citation_id
      # Los ⊗ no llevan evidencia sino redirección al paso que los cubre.
      t.bigint :guide_step_id
      t.timestamps

      t.index [ :verification_report_id, :dod_criterion_id ], unique: true
      t.index :result
    end

    create_table :ci_checks do |t|
      t.references :verification_report, null: false, foreign_key: true
      t.references :repository, null: false, foreign_key: true
      # El commit EJECUTADO, distinto del sellado en GATE 1.
      t.string :commit_sha, null: false
      t.string :ci_run_id
      t.string :ci_url
      # green · red · unavailable. El semáforo se compone de TODOS los checks
      # obligatorios, no solo de la suite: un lint en rojo con los tests en
      # verde sigue siendo un desarrollo que va a explotar.
      t.integer :status, null: false, default: 2
      t.integer :checks_passed
      t.integer :checks_failed
      t.integer :tests_total
      t.integer :tests_failed
      t.integer :duration_seconds
      t.timestamps

      t.index [ :verification_report_id, :repository_id ], unique: true
    end
  end
end
