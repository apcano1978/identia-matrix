# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_08_25_093231) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "adrs", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.string "code", null: false
    t.string "title", null: false
    t.bigint "origin_initiative_id"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["origin_initiative_id"], name: "index_adrs_on_origin_initiative_id"
    t.index ["repository_id", "code"], name: "index_adrs_on_repository_id_and_code", unique: true
    t.index ["repository_id"], name: "index_adrs_on_repository_id"
  end

  create_table "agent_configs", force: :cascade do |t|
    t.integer "agent", null: false
    t.bigint "platform_client_id"
    t.jsonb "settings", default: {}, null: false
    t.bigint "updated_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent", "platform_client_id"], name: "index_agent_configs_on_agent_and_platform_client_id", unique: true
    t.index ["platform_client_id"], name: "index_agent_configs_on_platform_client_id"
    t.index ["updated_by_user_id"], name: "index_agent_configs_on_updated_by_user_id"
  end

  create_table "agent_runs", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.integer "agent", null: false
    t.integer "purpose", null: false
    t.integer "iteration", default: 1, null: false
    t.integer "qa_cycle", default: 0, null: false
    t.string "code", null: false
    t.integer "status", default: 0, null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.integer "cost_cents"
    t.string "brain_request_id"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_agent_runs_on_code", unique: true
    t.index ["initiative_id", "agent", "purpose", "iteration"], name: "idx_agent_runs_one_live", unique: true, where: "(status = ANY (ARRAY[0, 1]))"
    t.index ["initiative_id"], name: "index_agent_runs_on_initiative_id"
  end

  create_table "artifacts", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.bigint "platform_client_id", null: false
    t.integer "kind", null: false
    t.string "code", null: false
    t.integer "version", default: 1, null: false
    t.string "storage_key", null: false
    t.string "checksum", null: false
    t.jsonb "front_matter", default: {}, null: false
    t.bigint "produced_by_run_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiative_id", "code", "version"], name: "index_artifacts_on_initiative_id_and_code_and_version", unique: true
    t.index ["initiative_id"], name: "index_artifacts_on_initiative_id"
    t.index ["platform_client_id"], name: "index_artifacts_on_platform_client_id"
    t.index ["produced_by_run_id"], name: "index_artifacts_on_produced_by_run_id"
    t.index ["storage_key"], name: "index_artifacts_on_storage_key", unique: true
  end

  create_table "ci_checks", force: :cascade do |t|
    t.bigint "verification_report_id", null: false
    t.bigint "repository_id", null: false
    t.string "commit_sha", null: false
    t.string "ci_run_id"
    t.string "ci_url"
    t.integer "status", default: 2, null: false
    t.integer "checks_passed"
    t.integer "checks_failed"
    t.integer "tests_total"
    t.integer "tests_failed"
    t.integer "duration_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id"], name: "index_ci_checks_on_repository_id"
    t.index ["verification_report_id", "repository_id"], name: "index_ci_checks_on_verification_report_id_and_repository_id", unique: true
    t.index ["verification_report_id"], name: "index_ci_checks_on_verification_report_id"
  end

  create_table "citation_conflicts", force: :cascade do |t|
    t.bigint "derived_citation_id", null: false
    t.bigint "origin_citation_id", null: false
    t.datetime "detected_at", null: false
    t.string "resolution"
    t.bigint "flagged_artifact_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["derived_citation_id"], name: "index_citation_conflicts_on_derived_citation_id"
    t.index ["flagged_artifact_id"], name: "index_citation_conflicts_on_flagged_artifact_id"
    t.index ["origin_citation_id"], name: "index_citation_conflicts_on_origin_citation_id"
  end

  create_table "citations", force: :cascade do |t|
    t.string "citable_type", null: false
    t.bigint "citable_id", null: false
    t.string "raw", null: false
    t.integer "source_kind", null: false
    t.bigint "repository_id"
    t.string "locator", null: false
    t.string "fragment"
    t.string "commit_sha"
    t.string "target_type"
    t.bigint "target_id"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "quote"
    t.index ["citable_type", "citable_id", "position"], name: "index_citations_on_citable_type_and_citable_id_and_position"
    t.index ["citable_type", "citable_id"], name: "index_citations_on_citable"
    t.index ["repository_id"], name: "index_citations_on_repository_id"
    t.index ["source_kind"], name: "index_citations_on_source_kind"
    t.index ["target_type", "target_id"], name: "index_citations_on_target"
  end

  create_table "definitions_of_done", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.string "code", null: false
    t.integer "version", default: 1, null: false
    t.bigint "authored_by_run_id"
    t.bigint "derived_from_artifact_id"
    t.bigint "reviewed_by_run_id"
    t.bigint "artifact_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["authored_by_run_id"], name: "index_definitions_of_done_on_authored_by_run_id"
    t.index ["initiative_id", "code", "version"], name: "idx_on_initiative_id_code_version_87c0fbf9fc", unique: true
    t.index ["initiative_id"], name: "index_definitions_of_done_on_initiative_id"
    t.index ["reviewed_by_run_id"], name: "index_definitions_of_done_on_reviewed_by_run_id"
  end

  create_table "dod_criteria", force: :cascade do |t|
    t.bigint "definition_of_done_id", null: false
    t.string "key", null: false
    t.text "statement", null: false
    t.integer "mandatory_kind"
    t.bigint "repository_id"
    t.bigint "trace_citation_id"
    t.string "test_ref"
    t.boolean "critical", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["definition_of_done_id", "key"], name: "index_dod_criteria_on_definition_of_done_id_and_key", unique: true
    t.index ["definition_of_done_id"], name: "index_dod_criteria_on_definition_of_done_id"
    t.index ["repository_id"], name: "index_dod_criteria_on_repository_id"
  end

  create_table "escalations", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.bigint "platform_client_id", null: false
    t.integer "reason", null: false
    t.datetime "opened_at", null: false
    t.bigint "opened_by_user_id"
    t.bigint "opened_by_verification_id"
    t.bigint "guide_step_id"
    t.datetime "resolved_at"
    t.bigint "resolved_by_user_id"
    t.bigint "human_note_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiative_id", "reason"], name: "index_escalations_on_initiative_id_and_reason"
    t.index ["initiative_id"], name: "index_escalations_on_initiative_id"
    t.index ["opened_by_user_id"], name: "index_escalations_on_opened_by_user_id"
    t.index ["platform_client_id"], name: "index_escalations_on_platform_client_id"
    t.index ["resolved_at"], name: "index_escalations_on_resolved_at"
    t.index ["resolved_by_user_id"], name: "index_escalations_on_resolved_by_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.datetime "occurred_at", null: false
    t.string "actor", null: false
    t.bigint "initiative_id"
    t.bigint "platform_client_id"
    t.string "kind", null: false
    t.string "message", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiative_id"], name: "index_events_on_initiative_id"
    t.index ["occurred_at"], name: "index_events_on_occurred_at"
    t.index ["platform_client_id"], name: "index_events_on_platform_client_id"
  end

  create_table "gate_signature_commits", force: :cascade do |t|
    t.bigint "gate_signature_id", null: false
    t.bigint "repository_id", null: false
    t.string "base_sha", null: false
    t.string "write_scope"
    t.integer "deploy_order", null: false
    t.string "executed_sha"
    t.bigint "executed_confirmed_by_id"
    t.datetime "executed_confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["executed_confirmed_by_id"], name: "index_gate_signature_commits_on_executed_confirmed_by_id"
    t.index ["gate_signature_id", "repository_id"], name: "idx_on_gate_signature_id_repository_id_a154cc5534", unique: true
    t.index ["gate_signature_id"], name: "index_gate_signature_commits_on_gate_signature_id"
    t.index ["repository_id"], name: "index_gate_signature_commits_on_repository_id"
  end

  create_table "gate_signatures", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.bigint "work_package_id", null: false
    t.string "package_hash", null: false
    t.bigint "signed_by_user_id", null: false
    t.string "identity", null: false
    t.datetime "signed_at", null: false
    t.text "statement", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiative_id"], name: "index_gate_signatures_on_initiative_id"
    t.index ["signed_by_user_id"], name: "index_gate_signatures_on_signed_by_user_id"
    t.index ["work_package_id"], name: "index_gate_signatures_on_work_package_id", unique: true
  end

  create_table "gate_validations", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.bigint "test_guide_id", null: false
    t.integer "decision", null: false
    t.bigint "decided_by_user_id", null: false
    t.datetime "decided_at", null: false
    t.jsonb "coverage_snapshot", default: {}, null: false
    t.text "rejection_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["decided_by_user_id"], name: "index_gate_validations_on_decided_by_user_id"
    t.index ["initiative_id", "decided_at"], name: "index_gate_validations_on_initiative_id_and_decided_at"
    t.index ["initiative_id"], name: "index_gate_validations_on_initiative_id"
    t.index ["test_guide_id"], name: "index_gate_validations_on_test_guide_id"
  end

  create_table "guide_steps", force: :cascade do |t|
    t.bigint "test_guide_id", null: false
    t.integer "position", null: false
    t.string "title", null: false
    t.text "body"
    t.integer "evidence_origin", null: false
    t.bigint "dod_criterion_id"
    t.datetime "walked_at"
    t.bigint "walked_by_user_id"
    t.text "walk_note"
    t.datetime "exempted_at"
    t.bigint "exempted_by_user_id"
    t.bigint "escalation_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dod_criterion_id"], name: "index_guide_steps_on_dod_criterion_id"
    t.index ["escalation_id"], name: "index_guide_steps_on_escalation_id"
    t.index ["exempted_by_user_id"], name: "index_guide_steps_on_exempted_by_user_id"
    t.index ["test_guide_id", "position"], name: "index_guide_steps_on_test_guide_id_and_position", unique: true
    t.index ["test_guide_id"], name: "index_guide_steps_on_test_guide_id"
    t.index ["walked_by_user_id"], name: "index_guide_steps_on_walked_by_user_id"
  end

  create_table "human_notes", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.bigint "platform_client_id", null: false
    t.bigint "author_user_id", null: false
    t.string "code", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_user_id"], name: "index_human_notes_on_author_user_id"
    t.index ["code"], name: "index_human_notes_on_code", unique: true
    t.index ["initiative_id"], name: "index_human_notes_on_initiative_id"
    t.index ["platform_client_id"], name: "index_human_notes_on_platform_client_id"
  end

  create_table "initiative_repositories", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.bigint "repository_id", null: false
    t.string "pinned_sha"
    t.integer "indexed_files_count"
    t.datetime "indexed_at"
    t.datetime "first_linked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "decision_note"
    t.index ["initiative_id", "repository_id"], name: "idx_on_initiative_id_repository_id_686c4d07d1", unique: true
    t.index ["initiative_id"], name: "index_initiative_repositories_on_initiative_id"
    t.index ["repository_id"], name: "index_initiative_repositories_on_repository_id"
  end

  create_table "initiative_roles", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.bigint "platform_user_id", null: false
    t.integer "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiative_id", "platform_user_id"], name: "idx_initiative_roles_unique", unique: true
    t.index ["initiative_id"], name: "index_initiative_roles_on_initiative_id"
    t.index ["platform_user_id"], name: "index_initiative_roles_on_platform_user_id"
  end

  create_table "initiative_sources", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.string "source_type", null: false
    t.bigint "source_id", null: false
    t.integer "refs_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiative_id", "source_type", "source_id"], name: "idx_initiative_sources_unique", unique: true
    t.index ["initiative_id"], name: "index_initiative_sources_on_initiative_id"
    t.index ["source_type", "source_id"], name: "index_initiative_sources_on_source"
  end

  create_table "initiatives", force: :cascade do |t|
    t.bigint "platform_client_id", null: false
    t.bigint "platform_project_id"
    t.string "code", null: false
    t.string "title", null: false
    t.integer "current_stage", default: 0, null: false
    t.integer "current_stage_status", default: 0, null: false
    t.integer "iteration", default: 1, null: false
    t.integer "qa_cycles_consumed", default: 0, null: false
    t.datetime "opened_at", null: false
    t.datetime "stage_changed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_initiatives_on_code", unique: true
    t.index ["platform_client_id", "current_stage"], name: "index_initiatives_on_platform_client_id_and_current_stage"
    t.index ["platform_client_id"], name: "index_initiatives_on_platform_client_id"
    t.index ["platform_project_id"], name: "index_initiatives_on_platform_project_id"
  end

  create_table "matrix_sequences", force: :cascade do |t|
    t.string "name", null: false
    t.integer "last_number", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_matrix_sequences_on_name", unique: true
  end

  create_table "platform_clients", force: :cascade do |t|
    t.bigint "platform_id", null: false
    t.string "slug", null: false
    t.string "name", null: false
    t.string "sector"
    t.string "city"
    t.string "status"
    t.string "primary_contact_role"
    t.boolean "archived", default: false, null: false
    t.datetime "synced_at"
    t.string "sync_source"
    t.datetime "missing_since"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "sources_synced_at"
    t.index ["platform_id"], name: "index_platform_clients_on_platform_id", unique: true
    t.index ["slug"], name: "index_platform_clients_on_slug", unique: true
  end

  create_table "platform_documents", force: :cascade do |t|
    t.bigint "platform_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.bigint "platform_client_id", null: false
    t.bigint "platform_project_id"
    t.text "body"
    t.datetime "source_updated_at"
    t.datetime "synced_at"
    t.string "sync_source"
    t.datetime "missing_since"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_client_id"], name: "index_platform_documents_on_platform_client_id"
    t.index ["platform_id"], name: "index_platform_documents_on_platform_id", unique: true
    t.index ["platform_project_id"], name: "index_platform_documents_on_platform_project_id"
    t.index ["slug"], name: "index_platform_documents_on_slug", unique: true
  end

  create_table "platform_meetings", force: :cascade do |t|
    t.bigint "platform_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.date "held_on", null: false
    t.bigint "platform_client_id", null: false
    t.bigint "platform_project_id"
    t.text "body"
    t.integer "duration_seconds"
    t.datetime "source_updated_at"
    t.datetime "synced_at"
    t.string "sync_source"
    t.datetime "missing_since"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["held_on"], name: "index_platform_meetings_on_held_on"
    t.index ["platform_client_id"], name: "index_platform_meetings_on_platform_client_id"
    t.index ["platform_id"], name: "index_platform_meetings_on_platform_id", unique: true
    t.index ["platform_project_id"], name: "index_platform_meetings_on_platform_project_id"
    t.index ["slug"], name: "index_platform_meetings_on_slug", unique: true
  end

  create_table "platform_projects", force: :cascade do |t|
    t.bigint "platform_id", null: false
    t.string "platform_project_ref", null: false
    t.string "name", null: false
    t.bigint "platform_client_id", null: false
    t.string "status"
    t.string "current_phase"
    t.date "started_on"
    t.date "estimated_end_on"
    t.boolean "archived", default: false, null: false
    t.datetime "synced_at"
    t.string "sync_source"
    t.datetime "missing_since"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_client_id"], name: "index_platform_projects_on_platform_client_id"
    t.index ["platform_id"], name: "index_platform_projects_on_platform_id", unique: true
    t.index ["platform_project_ref"], name: "index_platform_projects_on_platform_project_ref", unique: true
  end

  create_table "platform_users", force: :cascade do |t|
    t.bigint "platform_id", null: false
    t.string "email_address", null: false
    t.string "name", default: "", null: false
    t.integer "role", default: 0, null: false
    t.string "cargo"
    t.boolean "disabled", default: false, null: false
    t.datetime "synced_at"
    t.string "sync_source"
    t.datetime "missing_since"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_platform_users_on_email_address", unique: true
    t.index ["missing_since"], name: "index_platform_users_on_missing_since"
    t.index ["platform_id"], name: "index_platform_users_on_platform_id", unique: true
  end

  create_table "repositories", force: :cascade do |t|
    t.bigint "platform_client_id", null: false
    t.string "name", null: false
    t.string "default_branch", default: "main", null: false
    t.string "head_sha"
    t.integer "files_count"
    t.string "remote_url"
    t.string "ci_provider"
    t.string "ci_repo_slug"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_client_id", "name"], name: "index_repositories_on_platform_client_id_and_name", unique: true
    t.index ["platform_client_id"], name: "index_repositories_on_platform_client_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "platform_user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform_user_id"], name: "index_sessions_on_platform_user_id"
  end

  create_table "stage_entries", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.integer "stage", null: false
    t.integer "iteration", default: 1, null: false
    t.integer "status", default: 0, null: false
    t.integer "qa_cycle", default: 0, null: false
    t.datetime "entered_at"
    t.datetime "exited_at"
    t.string "summary"
    t.string "metric"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiative_id", "stage", "iteration"], name: "idx_stage_entries_unique_occurrence", unique: true
    t.index ["initiative_id"], name: "index_stage_entries_on_initiative_id"
  end

  create_table "test_guides", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.string "code", null: false
    t.bigint "verification_report_id", null: false
    t.bigint "artifact_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_test_guides_on_code", unique: true
    t.index ["initiative_id"], name: "index_test_guides_on_initiative_id"
    t.index ["verification_report_id"], name: "index_test_guides_on_verification_report_id"
  end

  create_table "verdicts", force: :cascade do |t|
    t.bigint "verification_report_id", null: false
    t.bigint "dod_criterion_id", null: false
    t.integer "result", null: false
    t.text "evidence"
    t.bigint "evidence_citation_id"
    t.bigint "guide_step_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dod_criterion_id"], name: "index_verdicts_on_dod_criterion_id"
    t.index ["result"], name: "index_verdicts_on_result"
    t.index ["verification_report_id", "dod_criterion_id"], name: "index_verdicts_on_verification_report_id_and_dod_criterion_id", unique: true
    t.index ["verification_report_id"], name: "index_verdicts_on_verification_report_id"
  end

  create_table "verification_reports", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.bigint "definition_of_done_id", null: false
    t.string "code", null: false
    t.bigint "agent_run_id"
    t.integer "iteration", default: 1, null: false
    t.integer "qa_cycle", default: 0, null: false
    t.integer "outcome", default: 0, null: false
    t.bigint "artifact_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_run_id"], name: "index_verification_reports_on_agent_run_id"
    t.index ["code"], name: "index_verification_reports_on_code", unique: true
    t.index ["definition_of_done_id"], name: "index_verification_reports_on_definition_of_done_id"
    t.index ["initiative_id"], name: "index_verification_reports_on_initiative_id"
  end

  create_table "work_package_repositories", force: :cascade do |t|
    t.bigint "work_package_id", null: false
    t.bigint "repository_id", null: false
    t.integer "deploy_order", null: false
    t.string "write_scope"
    t.text "compatibility_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id"], name: "index_work_package_repositories_on_repository_id"
    t.index ["work_package_id", "deploy_order"], name: "idx_on_work_package_id_deploy_order_52ae653729", unique: true
    t.index ["work_package_id", "repository_id"], name: "idx_on_work_package_id_repository_id_f2c31daf09", unique: true
    t.index ["work_package_id"], name: "index_work_package_repositories_on_work_package_id"
  end

  create_table "work_packages", force: :cascade do |t|
    t.bigint "initiative_id", null: false
    t.string "code", null: false
    t.bigint "agent_run_id"
    t.integer "tasks_count", default: 0, null: false
    t.integer "new_files_count", default: 0, null: false
    t.integer "modified_files_count", default: 0, null: false
    t.integer "migrations_count", default: 0, null: false
    t.datetime "sealed_at"
    t.string "content_hash"
    t.bigint "artifact_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_run_id"], name: "index_work_packages_on_agent_run_id"
    t.index ["code"], name: "index_work_packages_on_code", unique: true
    t.index ["initiative_id"], name: "index_work_packages_on_initiative_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "adrs", "initiatives", column: "origin_initiative_id"
  add_foreign_key "adrs", "repositories"
  add_foreign_key "agent_configs", "platform_clients"
  add_foreign_key "agent_configs", "platform_users", column: "updated_by_user_id"
  add_foreign_key "agent_runs", "initiatives"
  add_foreign_key "artifacts", "agent_runs", column: "produced_by_run_id"
  add_foreign_key "artifacts", "initiatives"
  add_foreign_key "artifacts", "platform_clients"
  add_foreign_key "ci_checks", "repositories"
  add_foreign_key "ci_checks", "verification_reports"
  add_foreign_key "citation_conflicts", "artifacts", column: "flagged_artifact_id"
  add_foreign_key "citation_conflicts", "citations", column: "derived_citation_id"
  add_foreign_key "citation_conflicts", "citations", column: "origin_citation_id"
  add_foreign_key "citations", "repositories"
  add_foreign_key "definitions_of_done", "agent_runs", column: "authored_by_run_id"
  add_foreign_key "definitions_of_done", "agent_runs", column: "reviewed_by_run_id"
  add_foreign_key "definitions_of_done", "artifacts"
  add_foreign_key "definitions_of_done", "artifacts", column: "derived_from_artifact_id"
  add_foreign_key "definitions_of_done", "initiatives"
  add_foreign_key "dod_criteria", "citations", column: "trace_citation_id"
  add_foreign_key "dod_criteria", "definitions_of_done"
  add_foreign_key "dod_criteria", "repositories"
  add_foreign_key "escalations", "guide_steps"
  add_foreign_key "escalations", "human_notes"
  add_foreign_key "escalations", "initiatives"
  add_foreign_key "escalations", "platform_clients"
  add_foreign_key "escalations", "platform_users", column: "opened_by_user_id"
  add_foreign_key "escalations", "platform_users", column: "resolved_by_user_id"
  add_foreign_key "escalations", "verification_reports", column: "opened_by_verification_id"
  add_foreign_key "events", "initiatives"
  add_foreign_key "events", "platform_clients"
  add_foreign_key "gate_signature_commits", "gate_signatures"
  add_foreign_key "gate_signature_commits", "platform_users", column: "executed_confirmed_by_id"
  add_foreign_key "gate_signature_commits", "repositories"
  add_foreign_key "gate_signatures", "initiatives"
  add_foreign_key "gate_signatures", "platform_users", column: "signed_by_user_id"
  add_foreign_key "gate_signatures", "work_packages"
  add_foreign_key "gate_validations", "initiatives"
  add_foreign_key "gate_validations", "platform_users", column: "decided_by_user_id"
  add_foreign_key "gate_validations", "test_guides"
  add_foreign_key "guide_steps", "dod_criteria"
  add_foreign_key "guide_steps", "escalations"
  add_foreign_key "guide_steps", "platform_users", column: "exempted_by_user_id"
  add_foreign_key "guide_steps", "platform_users", column: "walked_by_user_id"
  add_foreign_key "guide_steps", "test_guides"
  add_foreign_key "human_notes", "initiatives"
  add_foreign_key "human_notes", "platform_clients"
  add_foreign_key "human_notes", "platform_users", column: "author_user_id"
  add_foreign_key "initiative_repositories", "initiatives"
  add_foreign_key "initiative_repositories", "repositories"
  add_foreign_key "initiative_roles", "initiatives"
  add_foreign_key "initiative_roles", "platform_users"
  add_foreign_key "initiative_sources", "initiatives"
  add_foreign_key "initiatives", "platform_clients"
  add_foreign_key "initiatives", "platform_projects"
  add_foreign_key "platform_documents", "platform_clients"
  add_foreign_key "platform_documents", "platform_projects"
  add_foreign_key "platform_meetings", "platform_clients"
  add_foreign_key "platform_meetings", "platform_projects"
  add_foreign_key "platform_projects", "platform_clients"
  add_foreign_key "repositories", "platform_clients"
  add_foreign_key "sessions", "platform_users"
  add_foreign_key "stage_entries", "initiatives"
  add_foreign_key "test_guides", "artifacts"
  add_foreign_key "test_guides", "initiatives"
  add_foreign_key "test_guides", "verification_reports"
  add_foreign_key "verdicts", "citations", column: "evidence_citation_id"
  add_foreign_key "verdicts", "dod_criteria"
  add_foreign_key "verdicts", "guide_steps"
  add_foreign_key "verdicts", "verification_reports"
  add_foreign_key "verification_reports", "agent_runs"
  add_foreign_key "verification_reports", "artifacts"
  add_foreign_key "verification_reports", "definitions_of_done"
  add_foreign_key "verification_reports", "initiatives"
  add_foreign_key "work_package_repositories", "repositories"
  add_foreign_key "work_package_repositories", "work_packages"
  add_foreign_key "work_packages", "agent_runs"
  add_foreign_key "work_packages", "artifacts"
  add_foreign_key "work_packages", "initiatives"
end
