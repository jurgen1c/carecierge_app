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

ActiveRecord::Schema[8.1].define(version: 2026_09_05_170230) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "action_text_rich_texts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.uuid "uploaded_by_user_id"
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
    t.index ["uploaded_by_user_id"], name: "index_active_storage_blobs_on_uploaded_by_user_id"
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "approval_decisions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "approval_request_id", null: false
    t.datetime "created_at", null: false
    t.string "decision", null: false
    t.datetime "occurred_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["approval_request_id", "occurred_at"], name: "idx_on_approval_request_id_occurred_at_2164c1d00e"
    t.index ["approval_request_id"], name: "index_approval_decisions_on_approval_request_id"
    t.index ["user_id"], name: "index_approval_decisions_on_user_id"
    t.check_constraint "decision::text = ANY (ARRAY['approve'::character varying, 'reject'::character varying, 'edit'::character varying, 'defer'::character varying, 'dismiss'::character varying]::text[])", name: "approval_decisions_supported_decision"
  end

  create_table "approval_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action_key", null: false
    t.string "confidence"
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.datetime "deferred_until"
    t.string "kind", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "risk_level", null: false
    t.string "status", default: "pending", null: false
    t.uuid "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "subject_updated_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["subject_type", "subject_id"], name: "index_approval_requests_on_subject"
    t.index ["user_id", "status", "created_at"], name: "index_approval_requests_on_user_id_and_status_and_created_at"
    t.index ["user_id", "subject_type", "subject_id", "action_key"], name: "idx_approval_requests_one_open_action", unique: true, where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'deferred'::character varying])::text[]))"
    t.index ["user_id"], name: "index_approval_requests_on_user_id"
    t.check_constraint "confidence IS NULL OR (confidence::text = ANY (ARRAY['confirmed'::character varying, 'high'::character varying, 'medium'::character varying, 'low'::character varying, 'inferred'::character varying]::text[]))", name: "approval_requests_supported_confidence"
    t.check_constraint "risk_level::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying, 'sensitive'::character varying]::text[])", name: "approval_requests_supported_risk"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'deferred'::character varying, 'approved'::character varying, 'rejected'::character varying, 'dismissed'::character varying, 'superseded'::character varying]::text[])", name: "approval_requests_supported_status"
  end

  create_table "audit_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "actor_id"
    t.string "actor_kind", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.string "source", null: false
    t.uuid "target_id"
    t.string "target_type"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["action", "occurred_at"], name: "index_audit_events_on_action_and_occurred_at", order: { occurred_at: :desc }
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["occurred_at", "created_at", "id"], name: "index_audit_events_on_global_order", order: :desc
    t.index ["source", "occurred_at"], name: "index_audit_events_on_source_and_occurred_at", order: { occurred_at: :desc }
    t.index ["target_type", "target_id"], name: "index_audit_events_on_target_type_and_target_id"
    t.index ["user_id", "occurred_at"], name: "index_audit_events_on_user_id_and_occurred_at", order: { occurred_at: :desc }
    t.index ["user_id"], name: "index_audit_events_on_user_id"
    t.check_constraint "jsonb_typeof(metadata) = 'object'::text", name: "audit_events_metadata_is_object"
  end

  create_table "automation_permission_changes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "actor_id", null: false
    t.string "capability", null: false
    t.datetime "created_at", null: false
    t.string "new_mode"
    t.string "previous_mode"
    t.uuid "relationship_profile_id"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["actor_id"], name: "index_automation_permission_changes_on_actor_id"
    t.index ["relationship_profile_id", "created_at"], name: "idx_automation_permission_changes_relationship_time"
    t.index ["relationship_profile_id"], name: "index_automation_permission_changes_on_relationship_profile_id"
    t.index ["user_id", "created_at"], name: "index_automation_permission_changes_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_automation_permission_changes_on_user_id"
    t.check_constraint "action::text = 'removed'::text AND new_mode IS NULL OR (action::text = ANY (ARRAY['created'::character varying, 'updated'::character varying]::text[])) AND new_mode IS NOT NULL", name: "automation_permission_changes_action_mode_check"
    t.check_constraint "action::text = ANY (ARRAY['created'::character varying, 'updated'::character varying, 'removed'::character varying]::text[])", name: "automation_permission_changes_action_check"
    t.check_constraint "actor_id = user_id", name: "automation_permission_changes_actor_owner_check"
    t.check_constraint "capability::text = ANY (ARRAY['draft_messages'::character varying, 'send_reminders'::character varying, 'access_contacts'::character varying, 'access_calendar'::character varying, 'suggest_gifts'::character varying, 'contact_vendors'::character varying, 'send_invitations'::character varying, 'make_reservations'::character varying, 'make_purchases'::character varying, 'pay_deposits'::character varying, 'analyze_uploaded_social_content'::character varying, 'access_messages'::character varying]::text[])", name: "automation_permission_changes_capability_check"
    t.check_constraint "new_mode IS NULL OR (new_mode::text = ANY (ARRAY['disabled'::character varying, 'ask_every_time'::character varying, 'allow_automatically'::character varying]::text[]))", name: "automation_permission_changes_new_mode_check"
    t.check_constraint "previous_mode IS NULL OR (previous_mode::text = ANY (ARRAY['disabled'::character varying, 'ask_every_time'::character varying, 'allow_automatically'::character varying]::text[]))", name: "automation_permission_changes_previous_mode_check"
  end

  create_table "automation_permissions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "capability", null: false
    t.datetime "created_at", null: false
    t.string "mode", null: false
    t.uuid "relationship_profile_id"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["relationship_profile_id"], name: "index_automation_permissions_on_relationship_profile_id"
    t.index ["user_id", "capability"], name: "idx_automation_permissions_account_defaults", unique: true, where: "(relationship_profile_id IS NULL)"
    t.index ["user_id", "relationship_profile_id", "capability"], name: "idx_automation_permissions_relationship_overrides", unique: true, where: "(relationship_profile_id IS NOT NULL)"
    t.index ["user_id"], name: "index_automation_permissions_on_user_id"
    t.check_constraint "(capability::text <> ALL (ARRAY['make_purchases'::character varying, 'pay_deposits'::character varying, 'access_messages'::character varying]::text[])) OR mode::text <> 'allow_automatically'::text", name: "automation_permissions_high_impact_mode_check"
    t.check_constraint "capability::text = ANY (ARRAY['draft_messages'::character varying, 'send_reminders'::character varying, 'access_contacts'::character varying, 'access_calendar'::character varying, 'suggest_gifts'::character varying, 'contact_vendors'::character varying, 'send_invitations'::character varying, 'make_reservations'::character varying, 'make_purchases'::character varying, 'pay_deposits'::character varying, 'analyze_uploaded_social_content'::character varying, 'access_messages'::character varying]::text[])", name: "automation_permissions_capability_check"
    t.check_constraint "mode::text = ANY (ARRAY['disabled'::character varying, 'ask_every_time'::character varying, 'allow_automatically'::character varying]::text[])", name: "automation_permissions_mode_check"
  end

  create_table "backup_options", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "backup_plan_id", null: false
    t.text "change_summary", null: false
    t.string "cost_level", null: false
    t.datetime "created_at", null: false
    t.string "effort", null: false
    t.integer "estimated_cost_cents"
    t.integer "lock_version", default: 0, null: false
    t.integer "position", null: false
    t.text "preserved_constraints", null: false
    t.datetime "promoted_at"
    t.string "relationship_fit", null: false
    t.text "replacement_task_ids", null: false
    t.text "reviewed_reminders", null: false
    t.text "source_context", null: false
    t.text "summary", null: false
    t.text "task_blueprints", null: false
    t.string "timing", null: false
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.index ["backup_plan_id", "position"], name: "index_backup_options_on_backup_plan_id_and_position", unique: true
    t.index ["backup_plan_id"], name: "index_backup_options_on_backup_plan_id"
    t.check_constraint "\"position\" >= 0", name: "backup_options_position_nonnegative"
    t.check_constraint "cost_level::text = ANY (ARRAY['lower'::character varying, 'similar'::character varying, 'higher'::character varying, 'unknown'::character varying]::text[])", name: "backup_options_supported_cost_level"
    t.check_constraint "effort::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying]::text[])", name: "backup_options_supported_effort"
    t.check_constraint "estimated_cost_cents IS NULL OR estimated_cost_cents >= 0", name: "backup_options_estimated_cost_nonnegative"
    t.check_constraint "relationship_fit::text = ANY (ARRAY['strong'::character varying, 'good'::character varying, 'fair'::character varying]::text[])", name: "backup_options_supported_relationship_fit"
    t.check_constraint "timing::text = ANY (ARRAY['same_day'::character varying, 'within_week'::character varying, 'new_date'::character varying]::text[])", name: "backup_options_supported_timing"
  end

  create_table "backup_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "context_fingerprint", limit: 64, null: false
    t.datetime "created_at", null: false
    t.bigint "event_plan_generation_version", null: false
    t.uuid "event_plan_id", null: false
    t.datetime "generated_at", null: false
    t.boolean "include_private_notes", default: false, null: false
    t.boolean "include_vault_context", default: false, null: false
    t.string "locale", default: "en", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "promoted_at"
    t.string "scenario", null: false
    t.text "source_context", null: false
    t.string "status", default: "generated", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["event_plan_id", "status", "generated_at"], name: "index_backup_plans_on_plan_status_generated"
    t.index ["event_plan_id"], name: "index_backup_plans_on_event_plan_id"
    t.index ["user_id"], name: "index_backup_plans_on_user_id"
    t.check_constraint "context_fingerprint::text ~ '^[0-9a-f]{64}$'::text", name: "backup_plans_context_fingerprint_format"
    t.check_constraint "locale::text = ANY (ARRAY['en'::character varying, 'es'::character varying]::text[])", name: "backup_plans_supported_locale"
    t.check_constraint "scenario::text = ANY (ARRAY['weather'::character varying, 'vendor'::character varying, 'gift_delay'::character varying, 'restaurant_unavailable'::character varying, 'transportation'::character varying, 'illness_cancellation'::character varying]::text[])", name: "backup_plans_supported_scenario"
    t.check_constraint "status::text = ANY (ARRAY['generated'::character varying, 'promoted'::character varying, 'superseded'::character varying]::text[])", name: "backup_plans_supported_status"
  end

  create_table "bookings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "booking_kind", default: "reservation", null: false
    t.text "cancellation_policy"
    t.text "confirmation_details"
    t.datetime "created_at", null: false
    t.uuid "event_plan_id", null: false
    t.text "location"
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.uuid "plan_task_id"
    t.text "provider_name", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "planned", null: false
    t.string "time_zone", default: "UTC", null: false
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["event_plan_id", "starts_at", "id"], name: "index_bookings_on_event_plan_id_and_starts_at_and_id"
    t.index ["event_plan_id", "status", "starts_at"], name: "index_bookings_on_event_plan_id_and_status_and_starts_at"
    t.index ["event_plan_id"], name: "index_bookings_on_event_plan_id"
    t.index ["plan_task_id"], name: "index_bookings_on_unique_plan_task", unique: true, where: "(plan_task_id IS NOT NULL)"
    t.index ["user_id", "created_at"], name: "index_bookings_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_bookings_on_user_id"
    t.check_constraint "booking_kind::text = ANY (ARRAY['reservation'::character varying, 'booking'::character varying]::text[])", name: "bookings_supported_kind"
    t.check_constraint "status::text = ANY (ARRAY['planned'::character varying, 'requested'::character varying, 'confirmed'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[])", name: "bookings_supported_status"
  end

  create_table "calendar_connections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "access_token", null: false
    t.datetime "created_at", null: false
    t.string "granted_scopes", default: [], null: false, array: true
    t.datetime "last_error_at"
    t.string "last_error_code"
    t.datetime "last_sync_started_at"
    t.datetime "last_synced_at"
    t.string "locale", default: "en", null: false
    t.integer "lock_version", default: 0, null: false
    t.integer "pending_audit_count", default: 0, null: false
    t.string "provider", default: "google_calendar", null: false
    t.text "refresh_token", null: false
    t.boolean "resync_requested", default: false, null: false
    t.datetime "sync_lease_expires_at"
    t.uuid "sync_lease_token"
    t.string "sync_status", default: "connected", null: false
    t.string "sync_types", default: [], null: false, array: true
    t.datetime "token_expires_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["sync_status", "sync_lease_expires_at"], name: "index_calendar_connections_on_sync_lease"
    t.index ["user_id"], name: "index_calendar_connections_on_user_id", unique: true
    t.check_constraint "'https://www.googleapis.com/auth/calendar.events.owned'::text = ANY (granted_scopes::text[])", name: "calendar_connections_required_google_scope"
    t.check_constraint "last_error_code IS NULL OR (last_error_code::text = ANY (ARRAY['authorization_required'::character varying, 'calendar_authorization_incomplete'::character varying, 'calendar_permission_required'::character varying, 'invalid_grant'::character varying, 'invalid_provider_response'::character varying, 'provider_error'::character varying, 'provider_rejected'::character varying, 'provider_unavailable'::character varying, 'rate_limited'::character varying, 'revocation_failed'::character varying]::text[]))", name: "calendar_connections_supported_error_code"
    t.check_constraint "locale::text = ANY (ARRAY['en'::character varying, 'es'::character varying]::text[])", name: "calendar_connections_supported_locale"
    t.check_constraint "pending_audit_count >= 0", name: "calendar_connections_nonnegative_pending_audit_count"
    t.check_constraint "provider::text = 'google_calendar'::text", name: "calendar_connections_supported_provider"
    t.check_constraint "sync_status::text = 'syncing'::text AND sync_lease_token IS NOT NULL AND sync_lease_expires_at IS NOT NULL OR sync_status::text <> 'syncing'::text AND sync_lease_token IS NULL AND sync_lease_expires_at IS NULL", name: "calendar_connections_complete_sync_lease"
    t.check_constraint "sync_status::text = ANY (ARRAY['connected'::character varying, 'syncing'::character varying, 'failed'::character varying, 'action_required'::character varying]::text[])", name: "calendar_connections_supported_status"
    t.check_constraint "sync_types <@ ARRAY['important_dates'::character varying, 'reminders'::character varying, 'event_plans'::character varying, 'bookings'::character varying, 'commitments'::character varying]", name: "calendar_connections_supported_sync_types"
  end

  create_table "calendar_credential_revocations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "access_token"
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "last_error_code"
    t.integer "lock_version", default: 0, null: false
    t.text "refresh_token"
    t.datetime "retry_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["retry_at"], name: "index_calendar_credential_revocations_on_retry_at"
    t.index ["user_id"], name: "index_calendar_credential_revocations_on_user_id"
    t.check_constraint "access_token IS NOT NULL OR refresh_token IS NOT NULL", name: "calendar_credential_revocations_have_a_token"
  end

  create_table "calendar_event_syncs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "calendar_connection_id", null: false
    t.datetime "created_at", null: false
    t.text "external_event_id", null: false
    t.string "source_fingerprint", null: false
    t.uuid "source_id", null: false
    t.string "source_type", null: false
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index ["calendar_connection_id", "source_type", "source_id"], name: "index_calendar_event_syncs_on_connection_and_source", unique: true
    t.index ["calendar_connection_id"], name: "index_calendar_event_syncs_on_calendar_connection_id"
  end

  create_table "commitments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.date "due_on"
    t.text "notes"
    t.uuid "relationship_profile_id", null: false
    t.string "status", default: "open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "status", "due_on"], name: "idx_on_relationship_profile_id_status_due_on_109b7b7dd5"
    t.index ["relationship_profile_id"], name: "index_commitments_on_relationship_profile_id"
    t.index ["status", "due_on"], name: "index_commitments_on_open_due_on", where: "(((status)::text = 'open'::text) AND (due_on IS NOT NULL))"
  end

  create_table "contact_cadences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "interval_days", null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id"], name: "index_contact_cadences_on_relationship_profile_id", unique: true
    t.check_constraint "interval_days = ANY (ARRAY[7, 14, 30, 60, 90])", name: "contact_cadences_supported_interval_days"
  end

  create_table "contact_methods", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.string "label"
    t.boolean "preferred", default: false, null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["relationship_profile_id", "kind"], name: "index_contact_methods_on_relationship_profile_id_and_kind", unique: true
    t.index ["relationship_profile_id"], name: "index_contact_methods_on_relationship_profile_id"
  end

  create_table "contacts_connections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.datetime "last_refreshed_at"
    t.text "next_page_token"
    t.string "provider", default: "google_contacts", null: false
    t.text "refresh_token"
    t.string "status", default: "connected", null: false
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_contacts_connections_on_user_id", unique: true
  end

  create_table "conversation_recaps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.string "capture_source", default: "typed", null: false
    t.datetime "created_at", null: false
    t.datetime "extraction_approved_at"
    t.datetime "extraction_completed_at"
    t.string "extraction_error_code"
    t.datetime "extraction_requested_at"
    t.datetime "extraction_started_at"
    t.string "extraction_status", default: "not_requested", null: false
    t.datetime "occurred_at", null: false
    t.uuid "relationship_profile_id", null: false
    t.string "title", null: false
    t.text "transcript"
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "capture_source"], name: "idx_on_relationship_profile_id_capture_source_0d8af56d63"
    t.index ["relationship_profile_id", "extraction_status"], name: "idx_on_relationship_profile_id_extraction_status_90ce435e9b"
    t.index ["relationship_profile_id", "occurred_at"], name: "idx_on_relationship_profile_id_occurred_at_74ae112d81"
    t.index ["relationship_profile_id"], name: "index_conversation_recaps_on_relationship_profile_id"
  end

  create_table "data_migrations", primary_key: "version", id: :string, force: :cascade do |t|
  end

  create_table "deletion_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "account_digest", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "request_kind", null: false
    t.datetime "requested_at", null: false
    t.string "status", default: "pending", null: false
    t.uuid "subject_id"
    t.string "subject_type"
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["request_kind", "requested_at"], name: "index_deletion_requests_on_request_kind_and_requested_at"
    t.index ["subject_type", "subject_id"], name: "index_deletion_requests_on_subject_type_and_subject_id"
    t.index ["user_id"], name: "index_deletion_requests_on_user_id"
    t.check_constraint "request_kind::text = ANY (ARRAY['relationship_profile'::character varying, 'privacy_vault_item'::character varying, 'social_context_note'::character varying, 'ai_generated'::character varying, 'account'::character varying]::text[])", name: "deletion_requests_supported_kind"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'completed'::character varying, 'failed'::character varying]::text[])", name: "deletion_requests_supported_status"
  end

  create_table "desire_fulfillments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "desire_id", null: false
    t.date "fulfilled_on", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.index ["desire_id", "fulfilled_on"], name: "index_desire_fulfillments_on_desire_id_and_fulfilled_on"
    t.index ["desire_id"], name: "index_desire_fulfillments_on_desire_id"
  end

  create_table "desires", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "captured_on"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.uuid "relationship_profile_id", null: false
    t.string "source", default: "manual", null: false
    t.string "status", default: "active", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "captured_on"], name: "index_desires_on_relationship_profile_id_and_captured_on"
    t.index ["relationship_profile_id", "category"], name: "index_desires_on_relationship_profile_id_and_category"
    t.index ["relationship_profile_id", "status"], name: "index_desires_on_relationship_profile_id_and_status"
    t.index ["relationship_profile_id"], name: "index_desires_on_relationship_profile_id"
  end

  create_table "digest_deliveries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.datetime "dispatched_at"
    t.datetime "email_delivered_at"
    t.datetime "enqueued_at"
    t.text "error_message"
    t.datetime "handed_off_at"
    t.string "mode", null: false
    t.datetime "scheduled_for", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["enqueued_at"], name: "index_digest_deliveries_on_recoverable_lease", where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'dispatching'::character varying])::text[]))"
    t.index ["user_id", "scheduled_for"], name: "index_digest_deliveries_on_user_and_occurrence", unique: true
    t.index ["user_id"], name: "index_digest_deliveries_on_user_id"
    t.check_constraint "channel::text = ANY (ARRAY['email'::character varying, 'in_app'::character varying]::text[])", name: "digest_deliveries_supported_channel"
    t.check_constraint "mode::text = ANY (ARRAY['daily'::character varying, 'weekly'::character varying]::text[])", name: "digest_deliveries_supported_mode"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'dispatching'::character varying, 'dispatched'::character varying, 'skipped'::character varying, 'failed'::character varying, 'cancelled'::character varying]::text[])", name: "digest_deliveries_supported_status"
  end

  create_table "draft_revisions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "content", null: false
    t.jsonb "context_categories", default: [], null: false
    t.datetime "created_at", null: false
    t.uuid "message_draft_id", null: false
    t.string "origin", null: false
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.index ["message_draft_id", "position"], name: "index_draft_revisions_on_message_draft_id_and_position", unique: true
    t.index ["message_draft_id"], name: "index_draft_revisions_on_message_draft_id"
    t.check_constraint "\"position\" > 0", name: "draft_revisions_position_positive"
  end

  create_table "event_plan_vendors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "event_plan_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "vendor_id", null: false
    t.index ["event_plan_id", "vendor_id"], name: "index_event_plan_vendors_on_event_plan_id_and_vendor_id", unique: true
    t.index ["event_plan_id"], name: "index_event_plan_vendors_on_event_plan_id"
    t.index ["vendor_id"], name: "index_event_plan_vendors_on_vendor_id"
  end

  create_table "event_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "budget_cents"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "effort_level", default: "medium", null: false
    t.bigint "generation_version", default: 0, null: false
    t.text "guest_list"
    t.integer "lock_version", default: 0, null: false
    t.text "notes"
    t.string "occasion_type", null: false
    t.uuid "relationship_profile_id", null: false
    t.text "source_context", null: false
    t.date "starts_on"
    t.string "status", default: "active", null: false
    t.text "title", null: false
    t.string "tone", default: "warm", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["relationship_profile_id", "status", "starts_on"], name: "index_event_plans_on_profile_status_and_start"
    t.index ["relationship_profile_id"], name: "index_event_plans_on_relationship_profile_id"
    t.index ["user_id", "status", "starts_on"], name: "index_event_plans_on_user_id_and_status_and_starts_on"
    t.index ["user_id"], name: "index_event_plans_on_user_id"
    t.check_constraint "budget_cents IS NULL OR budget_cents >= 0", name: "event_plans_budget_nonnegative"
    t.check_constraint "effort_level::text = ANY (ARRAY['low'::character varying, 'medium'::character varying, 'high'::character varying]::text[])", name: "event_plans_supported_effort_level"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'completed'::character varying, 'archived'::character varying]::text[])", name: "event_plans_supported_status"
    t.check_constraint "tone::text = ANY (ARRAY['understated'::character varying, 'warm'::character varying, 'celebratory'::character varying, 'romantic'::character varying]::text[])", name: "event_plans_supported_tone"
  end

  create_table "external_provider_actions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action_kind", null: false
    t.uuid "booking_id"
    t.datetime "created_at", null: false
    t.uuid "event_plan_id"
    t.text "external_reference"
    t.text "failure_details"
    t.uuid "gift_purchase_plan_id"
    t.integer "lock_version", default: 0, null: false
    t.string "provider_kind", null: false
    t.text "provider_name", null: false
    t.datetime "recorded_at", null: false
    t.uuid "relationship_profile_id", null: false
    t.uuid "reminder_id"
    t.text "source_label", null: false
    t.text "source_url"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.uuid "vendor_quote_id"
    t.index ["booking_id"], name: "index_external_provider_actions_on_booking_id"
    t.index ["event_plan_id"], name: "index_external_provider_actions_on_event_plan_id"
    t.index ["gift_purchase_plan_id"], name: "index_external_provider_actions_on_gift_purchase_plan_id"
    t.index ["relationship_profile_id", "created_at", "id"], name: "index_provider_actions_on_profile_history"
    t.index ["relationship_profile_id"], name: "index_external_provider_actions_on_relationship_profile_id"
    t.index ["reminder_id"], name: "index_external_provider_actions_on_reminder_id"
    t.index ["user_id"], name: "index_external_provider_actions_on_user_id"
    t.index ["vendor_quote_id"], name: "index_external_provider_actions_on_vendor_quote_id"
  end

  create_table "extracted_memories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.uuid "canonical_memory_record_id"
    t.string "category", null: false
    t.string "confidence", null: false
    t.uuid "conversation_recap_id", null: false
    t.text "corrected_body"
    t.string "corrected_title"
    t.datetime "created_at", null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "reviewed_at"
    t.uuid "reviewed_by_id"
    t.text "source_excerpt", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["canonical_memory_record_id"], name: "index_extracted_memories_on_canonical_memory_record_id", unique: true
    t.index ["conversation_recap_id", "status"], name: "index_extracted_memories_on_conversation_recap_id_and_status"
    t.index ["conversation_recap_id"], name: "index_extracted_memories_on_conversation_recap_id"
    t.index ["relationship_profile_id", "status"], name: "index_extracted_memories_on_relationship_profile_id_and_status"
    t.index ["relationship_profile_id"], name: "index_extracted_memories_on_relationship_profile_id"
    t.index ["reviewed_by_id"], name: "index_extracted_memories_on_reviewed_by_id"
  end

  create_table "feature_flag_assignments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.uuid "feature_flag_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "target_kind", null: false
    t.string "target_value", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_flag_id", "target_kind", "target_value"], name: "index_feature_flag_assignments_on_flag_and_target", unique: true
    t.index ["feature_flag_id"], name: "index_feature_flag_assignments_on_feature_flag_id"
    t.index ["target_kind", "target_value"], name: "index_feature_flag_assignments_on_target_kind_and_target_value"
  end

  create_table "feature_flag_audit_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "actor_id"
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.uuid "feature_flag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_feature_flag_audit_events_on_action"
    t.index ["actor_id"], name: "index_feature_flag_audit_events_on_actor_id"
    t.index ["feature_flag_id"], name: "index_feature_flag_audit_events_on_feature_flag_id"
  end

  create_table "feature_flags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: false, null: false
    t.string "key", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "name", null: false
    t.datetime "retired_at"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_feature_flags_on_key", unique: true
    t.index ["retired_at"], name: "index_feature_flags_on_retired_at"
  end

  create_table "feed_item_states", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "dismissed_at"
    t.string "item_key", null: false
    t.datetime "snoozed_until"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id", "item_key"], name: "index_feed_item_states_on_user_id_and_item_key", unique: true
    t.index ["user_id", "snoozed_until"], name: "index_feed_item_states_on_user_id_and_snoozed_until", where: "(snoozed_until IS NOT NULL)"
    t.index ["user_id"], name: "index_feed_item_states_on_user_id"
    t.check_constraint "char_length(item_key::text) >= 1 AND char_length(item_key::text) <= 200", name: "feed_item_states_item_key_length"
    t.check_constraint "dismissed_at IS NOT NULL OR snoozed_until IS NOT NULL", name: "feed_item_states_active_state"
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.uuid "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "gift_purchase_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "budget", precision: 12, scale: 2
    t.text "constraints"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.string "delivery_status", default: "not_started", null: false
    t.date "expected_delivery_on"
    t.text "follow_up_notes"
    t.date "follow_up_on"
    t.uuid "gift_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "options", null: false
    t.uuid "plan_task_id"
    t.date "purchase_by"
    t.string "purchase_status", default: "planning", null: false
    t.text "shipping_notes"
    t.datetime "updated_at", null: false
    t.index ["gift_id"], name: "index_gift_purchase_plans_on_gift_id", unique: true
    t.index ["plan_task_id"], name: "index_gift_purchase_plans_on_plan_task_id"
  end

  create_table "gift_recommendations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "allow_repeats", default: false, null: false
    t.integer "budget_cents"
    t.datetime "created_at", null: false
    t.datetime "dismissed_at"
    t.integer "estimated_price_cents"
    t.datetime "generated_at", null: false
    t.uuid "gift_id"
    t.boolean "include_private_notes", default: false, null: false
    t.boolean "include_vault_context", default: false, null: false
    t.string "locale", default: "en", null: false
    t.integer "lock_version", default: 0, null: false
    t.date "needed_by"
    t.text "occasion"
    t.datetime "purchased_at"
    t.text "rationale", null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "saved_at"
    t.text "source_context", null: false
    t.string "status", default: "generated", null: false
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.text "vendor"
    t.index ["gift_id"], name: "index_gift_recommendations_on_gift_id"
    t.index ["relationship_profile_id", "status", "generated_at"], name: "index_gift_recommendations_on_profile_status_generated"
    t.index ["relationship_profile_id"], name: "index_gift_recommendations_on_relationship_profile_id"
    t.index ["user_id"], name: "index_gift_recommendations_on_user_id"
    t.check_constraint "budget_cents IS NULL OR budget_cents >= 0", name: "gift_recommendations_budget_nonnegative"
    t.check_constraint "estimated_price_cents IS NULL OR estimated_price_cents >= 0", name: "gift_recommendations_estimated_price_nonnegative"
    t.check_constraint "status::text = ANY (ARRAY['generated'::character varying, 'saved'::character varying, 'dismissed'::character varying, 'purchased'::character varying]::text[])", name: "gift_recommendations_supported_status"
  end

  create_table "gift_box_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "completed", default: false, null: false
    t.decimal "cost", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.uuid "gift_box_id", null: false
    t.text "name", null: false
    t.text "notes"
    t.text "purchase_url"
    t.boolean "purchased", default: false, null: false
    t.datetime "updated_at", null: false
    t.text "vendor"
    t.index ["gift_box_id"], name: "index_gift_box_items_on_gift_box_id"
  end

  create_table "gift_boxes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "budget", precision: 12, scale: 2
    t.text "constraints"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.date "delivery_on"
    t.integer "lock_version", default: 0, null: false
    t.text "name", null: false
    t.text "notes"
    t.text "occasion", null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id"], name: "index_gift_boxes_on_relationship_profile_id"
  end

  create_table "gifts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "given_on"
    t.string "name", null: false
    t.text "notes"
    t.string "occasion"
    t.string "outcome"
    t.integer "price_cents"
    t.text "reaction"
    t.uuid "relationship_profile_id", null: false
    t.string "status", default: "idea", null: false
    t.datetime "updated_at", null: false
    t.string "vendor"
    t.index "relationship_profile_id, lower((name)::text)", name: "index_gifts_on_profile_and_lower_name"
    t.index ["relationship_profile_id", "given_on"], name: "index_gifts_on_relationship_profile_id_and_given_on"
    t.index ["relationship_profile_id", "outcome"], name: "index_gifts_on_relationship_profile_id_and_outcome"
    t.index ["relationship_profile_id", "status"], name: "index_gifts_on_relationship_profile_id_and_status"
    t.index ["relationship_profile_id"], name: "index_gifts_on_relationship_profile_id"
  end

  create_table "important_dates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "date_type", null: false
    t.string "importance_level", default: "normal", null: false
    t.text "notes"
    t.string "recurrence", default: "none", null: false
    t.uuid "relationship_profile_id", null: false
    t.string "reminder_schedule", default: "none", null: false
    t.date "starts_on", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "date_type"], name: "index_important_dates_on_relationship_profile_id_and_date_type"
    t.index ["relationship_profile_id", "importance_level"], name: "idx_on_relationship_profile_id_importance_level_a07d6afa11"
    t.index ["relationship_profile_id", "starts_on"], name: "index_important_dates_on_relationship_profile_id_and_starts_on"
    t.index ["relationship_profile_id"], name: "index_important_dates_on_relationship_profile_id"
  end

  create_table "imported_contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "applied_data"
    t.uuid "contacts_connection_id", null: false
    t.datetime "created_at", null: false
    t.text "data", null: false
    t.string "decision", default: "pending", null: false
    t.text "external_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "previous_data"
    t.string "provider_key", null: false
    t.uuid "relationship_profile_id"
    t.datetime "updated_at", null: false
    t.index ["contacts_connection_id", "provider_key"], name: "idx_on_contacts_connection_id_provider_key_a5445e4db7", unique: true
    t.index ["contacts_connection_id"], name: "index_imported_contacts_on_contacts_connection_id"
    t.index ["relationship_profile_id"], name: "index_imported_contacts_on_relationship_profile_id"
  end

  create_table "imported_message_contexts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "external_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "messaging_connection_id", null: false
    t.boolean "reply_ai_generated", default: false, null: false
    t.text "reply_draft"
    t.text "snippet", null: false
    t.string "source_key", null: false
    t.text "subject", null: false
    t.text "thread_id", null: false
    t.datetime "updated_at", null: false
    t.index ["messaging_connection_id", "source_key"], name: "idx_on_messaging_connection_id_source_key_d6f9fe6c82", unique: true
    t.index ["messaging_connection_id"], name: "index_imported_message_contexts_on_messaging_connection_id"
  end

  create_table "interactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "interaction_type", null: false
    t.text "notes"
    t.datetime "occurred_at", null: false
    t.string "origin", default: "manual", null: false
    t.uuid "relationship_profile_id", null: false
    t.uuid "source_id"
    t.string "source_type"
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "occurred_at", "id"], name: "idx_on_relationship_profile_id_occurred_at_id_afacfa9a3b", order: { occurred_at: :desc }
    t.index ["relationship_profile_id"], name: "index_interactions_on_relationship_profile_id"
    t.index ["source_type", "source_id"], name: "index_interactions_on_unique_source", unique: true, where: "(source_id IS NOT NULL)"
    t.check_constraint "interaction_type::text = ANY (ARRAY['call'::character varying, 'message'::character varying, 'in_person'::character varying, 'video'::character varying, 'other'::character varying, 'conversation_recap'::character varying, 'mood_note'::character varying]::text[])", name: "interactions_supported_type"
    t.check_constraint "origin::text = 'manual'::text AND (interaction_type::text = ANY (ARRAY['call'::character varying, 'message'::character varying, 'in_person'::character varying, 'video'::character varying, 'other'::character varying]::text[])) OR origin::text = 'derived'::text AND (interaction_type::text = ANY (ARRAY['conversation_recap'::character varying, 'mood_note'::character varying]::text[]))", name: "interactions_origin_matches_type"
    t.check_constraint "origin::text = 'manual'::text AND source_id IS NULL AND source_type IS NULL OR origin::text = 'derived'::text AND source_id IS NOT NULL AND source_type IS NOT NULL", name: "interactions_origin_matches_source"
    t.check_constraint "origin::text = ANY (ARRAY['manual'::character varying, 'derived'::character varying]::text[])", name: "interactions_supported_origin"
  end

  create_table "marketplace_listings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "curated_summary", null: false
    t.string "name", null: false
    t.string "occasion_types", default: [], null: false, array: true
    t.text "provider_details", null: false
    t.string "provider_name", null: false
    t.boolean "published", default: false, null: false
    t.text "relationship_use_cases", null: false
    t.date "reviewed_on", null: false
    t.string "service_area", null: false
    t.string "source_url", null: false
    t.datetime "updated_at", null: false
    t.index ["published", "category"], name: "index_marketplace_listings_on_published_and_category"
  end

  create_table "memory_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.string "confidence", default: "confirmed", null: false
    t.datetime "created_at", null: false
    t.datetime "high_impact_automation_approved_at"
    t.uuid "relationship_profile_id", null: false
    t.datetime "review_queued_at"
    t.datetime "reviewed_at"
    t.string "source", default: "user_confirmed", null: false
    t.date "stale_after"
    t.string "status", default: "active", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "confidence"], name: "index_memory_records_on_relationship_profile_id_and_confidence"
    t.index ["relationship_profile_id", "source"], name: "index_memory_records_on_relationship_profile_id_and_source"
    t.index ["relationship_profile_id", "stale_after"], name: "idx_on_relationship_profile_id_stale_after_ff6eff736b"
    t.index ["relationship_profile_id", "status"], name: "index_memory_records_on_relationship_profile_id_and_status"
    t.index ["relationship_profile_id"], name: "index_memory_records_on_relationship_profile_id"
  end

  create_table "memory_revisions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "memory_record_id", null: false
    t.text "note"
    t.text "previous_body", null: false
    t.text "revised_body", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.index ["memory_record_id", "created_at"], name: "index_memory_revisions_on_memory_record_id_and_created_at"
    t.index ["memory_record_id"], name: "index_memory_revisions_on_memory_record_id"
    t.index ["user_id"], name: "index_memory_revisions_on_user_id"
  end

  create_table "message_drafts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "draft_type", null: false
    t.string "formality", default: "balanced", null: false
    t.uuid "relationship_profile_id", null: false
    t.string "response_length", default: "medium", null: false
    t.text "situation", default: "", null: false
    t.string "tone", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["relationship_profile_id"], name: "index_message_drafts_on_relationship_profile_id", unique: true
    t.index ["user_id"], name: "index_message_drafts_on_user_id"
    t.check_constraint "char_length(situation) <= 4000", name: "message_drafts_situation_length"
    t.check_constraint "formality::text = ANY (ARRAY['casual'::character varying, 'balanced'::character varying, 'formal'::character varying]::text[])", name: "message_drafts_formality"
    t.check_constraint "response_length::text = ANY (ARRAY['short'::character varying, 'medium'::character varying, 'long'::character varying]::text[])", name: "message_drafts_response_length"
  end

  create_table "messaging_connections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.text "mailbox_email"
    t.string "provider", default: "gmail", null: false
    t.text "refresh_token"
    t.string "status", default: "connected", null: false
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_messaging_connections_on_user_id", unique: true
  end

  create_table "mood_notes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "follow_up_at"
    t.text "observation", null: false
    t.datetime "observed_at", null: false
    t.uuid "relationship_profile_id", null: false
    t.text "supportive_action"
    t.boolean "timeline_visible", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "category"], name: "index_mood_notes_on_relationship_profile_id_and_category"
    t.index ["relationship_profile_id", "follow_up_at"], name: "index_mood_notes_on_relationship_profile_id_and_follow_up_at"
    t.index ["relationship_profile_id", "observed_at"], name: "index_mood_notes_on_relationship_profile_id_and_observed_at"
    t.index ["relationship_profile_id"], name: "index_mood_notes_on_relationship_profile_id"
  end

  create_table "noticed_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.jsonb "params"
    t.uuid "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "event_id", null: false
    t.datetime "read_at", precision: nil
    t.uuid "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "notification_preferences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "digest_channel", default: "email", null: false
    t.string "digest_mode", default: "off", null: false
    t.datetime "digest_schedule_changed_at"
    t.time "digest_time", default: "2000-01-01 09:00:00", null: false
    t.integer "digest_weekday", default: 1, null: false
    t.boolean "email_enabled", default: true, null: false
    t.boolean "high_priority_alerts_enabled", default: true, null: false
    t.boolean "in_app_enabled", default: true, null: false
    t.boolean "push_enabled", default: false, null: false
    t.boolean "quiet_hours_enabled", default: false, null: false
    t.time "quiet_hours_end", default: "2000-01-01 07:00:00", null: false
    t.time "quiet_hours_start", default: "2000-01-01 22:00:00", null: false
    t.string "reminder_frequency", default: "none", null: false
    t.integer "reminder_lead_minutes", default: 1440, null: false
    t.boolean "sms_enabled", default: false, null: false
    t.string "time_zone", default: "UTC", null: false
    t.boolean "time_zone_configured", default: false, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_notification_preferences_on_user_id", unique: true
    t.check_constraint "digest_channel::text = ANY (ARRAY['email'::character varying, 'in_app'::character varying]::text[])", name: "notification_preferences_supported_digest_channel"
    t.check_constraint "digest_mode::text = ANY (ARRAY['off'::character varying, 'daily'::character varying, 'weekly'::character varying]::text[])", name: "notification_preferences_supported_digest_mode"
    t.check_constraint "digest_weekday >= 0 AND digest_weekday <= 6", name: "notification_preferences_supported_digest_weekday"
    t.check_constraint "reminder_frequency::text = ANY (ARRAY['none'::character varying, 'daily'::character varying, 'weekly'::character varying, 'monthly'::character varying, 'yearly'::character varying]::text[])", name: "notification_preferences_supported_reminder_frequency"
    t.check_constraint "reminder_lead_minutes = ANY (ARRAY[0, 60, 1440, 10080, 20160, 43200])", name: "notification_preferences_supported_reminder_lead"
  end

  create_table "personal_touch_checklists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "event_plan_id"
    t.uuid "important_date_id"
    t.uuid "relationship_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_plan_id"], name: "idx_personal_touch_checklists_unique_event_plan", unique: true, where: "(event_plan_id IS NOT NULL)"
    t.index ["important_date_id"], name: "idx_personal_touch_checklists_unique_important_date", unique: true, where: "(important_date_id IS NOT NULL)"
    t.index ["relationship_profile_id"], name: "index_personal_touch_checklists_on_relationship_profile_id"
    t.check_constraint "(event_plan_id IS NOT NULL) <> (important_date_id IS NOT NULL)", name: "personal_touch_checklists_exactly_one_moment"
  end

  create_table "personal_touch_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "details"
    t.datetime "dismissed_at"
    t.string "origin", default: "manual", null: false
    t.uuid "personal_touch_checklist_id", null: false
    t.integer "position", default: 0, null: false
    t.text "source_context", default: "[]", null: false
    t.string "status", default: "active", null: false
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.index ["personal_touch_checklist_id", "status", "position"], name: "idx_personal_touch_items_checklist_status_position"
    t.index ["personal_touch_checklist_id"], name: "index_personal_touch_items_on_personal_touch_checklist_id"
    t.check_constraint "category::text = ANY (ARRAY['preference'::character varying, 'constraint'::character varying, 'message'::character varying, 'gift'::character varying, 'dietary_need'::character varying, 'accessibility_need'::character varying, 'logistics'::character varying, 'follow_up'::character varying]::text[])", name: "personal_touch_items_category"
    t.check_constraint "origin::text = ANY (ARRAY['manual'::character varying, 'suggested'::character varying]::text[])", name: "personal_touch_items_origin"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'completed'::character varying, 'dismissed'::character varying]::text[])", name: "personal_touch_items_status"
  end

  create_table "plan_tasks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "backup_option_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "details"
    t.date "due_on"
    t.uuid "event_plan_id", null: false
    t.string "kind", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "origin", default: "manual", null: false
    t.string "phase", null: false
    t.integer "position", null: false
    t.text "source_context", null: false
    t.datetime "superseded_at"
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.index ["backup_option_id"], name: "index_plan_tasks_on_backup_option_id"
    t.index ["event_plan_id", "completed_at", "due_on"], name: "index_plan_tasks_on_plan_completion_and_due"
    t.index ["event_plan_id", "phase", "position"], name: "index_plan_tasks_on_plan_phase_position"
    t.index ["event_plan_id", "superseded_at"], name: "index_plan_tasks_on_plan_and_superseded"
    t.index ["event_plan_id"], name: "index_plan_tasks_on_event_plan_id"
    t.check_constraint "\"position\" >= 0", name: "plan_tasks_position_nonnegative"
    t.check_constraint "kind::text = ANY (ARRAY['decision'::character varying, 'task'::character varying, 'reminder'::character varying, 'vendor_need'::character varying, 'gift_idea'::character varying, 'message_draft'::character varying, 'backup_step'::character varying, 'milestone'::character varying]::text[])", name: "plan_tasks_supported_kind"
    t.check_constraint "origin::text = ANY (ARRAY['manual'::character varying, 'template'::character varying, 'ai'::character varying]::text[])", name: "plan_tasks_supported_origin"
    t.check_constraint "phase::text = ANY (ARRAY['decide'::character varying, 'arrange'::character varying, 'follow_through'::character varying]::text[])", name: "plan_tasks_supported_phase"
  end

  create_table "privacy_vault_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "payload", null: false
    t.uuid "protectable_id", null: false
    t.string "protectable_type", null: false
    t.datetime "protected_at", null: false
    t.uuid "relationship_profile_id", null: false
    t.string "suggestion_usage", default: "excluded", null: false
    t.datetime "updated_at", null: false
    t.index ["protectable_type", "protectable_id"], name: "index_privacy_vault_items_on_protectable", unique: true
    t.index ["relationship_profile_id", "protected_at"], name: "idx_on_relationship_profile_id_protected_at_06b534e13e"
    t.index ["relationship_profile_id"], name: "index_privacy_vault_items_on_relationship_profile_id"
    t.check_constraint "protectable_type::text = ANY (ARRAY['MemoryRecord'::character varying, 'RelationshipFieldValue'::character varying, 'RelationshipNote'::character varying]::text[])", name: "privacy_vault_items_supported_protectable_type"
    t.check_constraint "suggestion_usage::text = ANY (ARRAY['excluded'::character varying, 'allowed'::character varying]::text[])", name: "privacy_vault_items_supported_suggestion_usage"
  end

  create_table "relationship_briefings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.jsonb "context_categories", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "dismissed_at"
    t.datetime "generated_at", null: false
    t.boolean "include_private_notes", default: false, null: false
    t.boolean "include_vault_context", default: false, null: false
    t.text "interaction_context", null: false
    t.string "locale", default: "en", null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "saved_at"
    t.text "sections", null: false
    t.string "status", default: "generated", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["relationship_profile_id", "generated_at"], name: "index_relationship_briefings_on_profile_and_generated_at", order: { generated_at: :desc }
    t.index ["relationship_profile_id"], name: "index_relationship_briefings_on_one_generated_per_profile", unique: true, where: "((status)::text = 'generated'::text)"
    t.index ["relationship_profile_id"], name: "index_relationship_briefings_on_relationship_profile_id"
    t.index ["user_id"], name: "index_relationship_briefings_on_user_id"
    t.check_constraint "jsonb_typeof(context_categories) = 'array'::text", name: "relationship_briefings_context_categories_array"
    t.check_constraint "locale::text = ANY (ARRAY['en'::character varying, 'es'::character varying]::text[])", name: "relationship_briefings_supported_locale"
    t.check_constraint "status::text = ANY (ARRAY['generated'::character varying, 'saved'::character varying, 'dismissed'::character varying]::text[])", name: "relationship_briefings_supported_status"
  end

  create_table "relationship_field_values", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "custom", default: false, null: false
    t.boolean "hidden", default: false, null: false
    t.string "key"
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.uuid "relationship_profile_id", null: false
    t.uuid "template_field_id"
    t.datetime "updated_at", null: false
    t.text "value"
    t.index "relationship_profile_id, lower((label)::text)", name: "index_relationship_field_values_on_profile_and_lower_label", unique: true, where: "(custom = true)"
    t.index ["relationship_profile_id", "hidden", "position"], name: "index_relationship_field_values_on_profile_hidden_position"
    t.index ["relationship_profile_id", "template_field_id"], name: "index_relationship_field_values_on_profile_and_template_field", unique: true, where: "(template_field_id IS NOT NULL)"
    t.index ["relationship_profile_id"], name: "index_relationship_field_values_on_relationship_profile_id"
    t.index ["template_field_id"], name: "index_relationship_field_values_on_template_field_id"
  end

  create_table "relationship_group_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "relationship_group_id", null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_group_id"], name: "index_relationship_group_memberships_on_relationship_group_id"
    t.index ["relationship_profile_id", "relationship_group_id"], name: "index_relationship_group_memberships_on_profile_and_group", unique: true
    t.index ["relationship_profile_id"], name: "idx_on_relationship_profile_id_5e33b2c4bc"
  end

  create_table "relationship_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_relationship_groups_on_user_id_and_lower_name", unique: true
    t.index ["user_id"], name: "index_relationship_groups_on_user_id"
  end

  create_table "relationship_notes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.boolean "private", default: false, null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "private"], name: "idx_on_relationship_profile_id_private_777e9fc47b"
    t.index ["relationship_profile_id"], name: "index_relationship_notes_on_relationship_profile_id"
  end

  create_table "relationship_notification_preferences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "mode", default: "muted", null: false
    t.uuid "notification_preference_id", null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["notification_preference_id"], name: "idx_on_notification_preference_id_f719334035"
    t.index ["relationship_profile_id"], name: "idx_on_relationship_profile_id_ed7238d212", unique: true
    t.check_constraint "mode::text = 'muted'::text", name: "relationship_notification_preferences_supported_mode"
  end

  create_table "relationship_preferences", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "category", default: "general", null: false
    t.string "confidence", default: "inferred", null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.date "learned_on"
    t.string "preference_type", default: "neutral", null: false
    t.uuid "relationship_profile_id", null: false
    t.text "source_notes"
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index "relationship_profile_id, lower((key)::text)", name: "idx_relationship_preferences_on_profile_and_lower_key", unique: true
    t.index ["relationship_profile_id", "category"], name: "idx_on_relationship_profile_id_category_de91ce2a16"
    t.index ["relationship_profile_id", "confidence"], name: "idx_on_relationship_profile_id_confidence_1dd4e61f57"
    t.index ["relationship_profile_id", "preference_type"], name: "idx_on_relationship_profile_id_preference_type_3701ad82f6"
    t.index ["relationship_profile_id"], name: "index_relationship_preferences_on_relationship_profile_id"
  end

  create_table "relationship_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "birthday"
    t.bigint "briefing_generation_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "first_name", null: false
    t.bigint "gift_recommendation_generation_version", default: 0, null: false
    t.string "last_name"
    t.bigint "message_draft_generation_version", default: 0, null: false
    t.string "preferred_name"
    t.jsonb "profile_attributes", default: {}, null: false
    t.string "pronouns"
    t.string "slug"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["first_name"], name: "index_relationship_profiles_on_first_name"
    t.index ["last_name"], name: "index_relationship_profiles_on_last_name"
    t.index ["preferred_name"], name: "index_relationship_profiles_on_preferred_name"
    t.index ["slug"], name: "index_relationship_profiles_on_slug", unique: true
    t.index ["type"], name: "index_relationship_profiles_on_type"
    t.index ["user_id", "discarded_at"], name: "index_relationship_profiles_on_user_id_and_discarded_at"
    t.index ["user_id"], name: "index_relationship_profiles_on_user_id"
  end

  create_table "relationship_taggings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "relationship_profile_id", null: false
    t.uuid "relationship_tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "relationship_tag_id"], name: "index_relationship_taggings_on_profile_and_tag", unique: true
    t.index ["relationship_profile_id"], name: "index_relationship_taggings_on_relationship_profile_id"
    t.index ["relationship_tag_id"], name: "index_relationship_taggings_on_relationship_tag_id"
  end

  create_table "relationship_tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_relationship_tags_on_user_id_and_lower_name", unique: true
    t.index ["user_id"], name: "index_relationship_tags_on_user_id"
  end

  create_table "relationship_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.string "relationship_type", null: false
    t.boolean "system", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_relationship_templates_on_active_and_position"
    t.index ["key"], name: "index_relationship_templates_on_key", unique: true
    t.index ["relationship_type"], name: "index_relationship_templates_on_relationship_type", unique: true
  end

  create_table "reminder_deliveries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.datetime "dispatched_at"
    t.datetime "enqueued_at"
    t.text "error_message"
    t.uuid "lease_token"
    t.uuid "noticed_event_id"
    t.uuid "reminder_id", null: false
    t.datetime "scheduled_for", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["enqueued_at"], name: "index_reminder_deliveries_on_recoverable_lease", where: "((status)::text = ANY ((ARRAY['pending'::character varying, 'dispatching'::character varying])::text[]))"
    t.index ["noticed_event_id"], name: "index_reminder_deliveries_on_noticed_event_id", unique: true
    t.index ["reminder_id", "channel", "scheduled_for"], name: "index_reminder_deliveries_on_occurrence_and_channel", unique: true
    t.index ["reminder_id"], name: "index_reminder_deliveries_on_reminder_id"
  end

  create_table "reminders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "booking_id"
    t.string "booking_milestone"
    t.uuid "commitment_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.uuid "event_plan_id"
    t.uuid "important_date_id"
    t.datetime "next_delivery_at"
    t.text "notes"
    t.uuid "plan_task_id"
    t.string "priority", default: "normal", null: false
    t.string "recurrence", default: "none", null: false
    t.datetime "recurrence_anchor_at", null: false
    t.uuid "relationship_profile_id"
    t.string "reminder_type", default: "custom", null: false
    t.datetime "scheduled_at", null: false
    t.datetime "snoozed_until"
    t.string "status", default: "active", null: false
    t.string "time_zone", default: "UTC", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.uuid "vendor_quote_id"
    t.index ["booking_id"], name: "index_reminders_on_booking_id"
    t.index ["commitment_id"], name: "index_reminders_on_commitment_id"
    t.index ["event_plan_id"], name: "index_reminders_on_event_plan_id"
    t.index ["important_date_id"], name: "index_reminders_on_important_date_id"
    t.index ["next_delivery_at"], name: "index_reminders_on_active_next_delivery_at", where: "(((status)::text = 'active'::text) AND (next_delivery_at IS NOT NULL))"
    t.index ["plan_task_id"], name: "index_reminders_on_plan_task_id"
    t.index ["relationship_profile_id", "status", "scheduled_at"], name: "index_reminders_on_profile_status_and_schedule"
    t.index ["relationship_profile_id"], name: "index_reminders_on_relationship_profile_id"
    t.index ["user_id", "status", "scheduled_at"], name: "index_reminders_on_user_id_and_status_and_scheduled_at"
    t.index ["user_id"], name: "index_reminders_on_user_id"
    t.index ["vendor_quote_id"], name: "index_reminders_on_vendor_quote_id"
  end

  create_table "rollout_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "criteria", default: {}, null: false
    t.text "description"
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "retired_at"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_rollout_groups_on_key", unique: true
    t.index ["retired_at"], name: "index_rollout_groups_on_retired_at"
  end

  create_table "shared_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "assignee_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.uuid "creator_id", null: false
    t.text "details"
    t.datetime "due_at"
    t.string "editing", default: "creator", null: false
    t.string "kind", null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "parent_id"
    t.uuid "shared_relationship_space_id", null: false
    t.string "time_zone", default: "UTC", null: false
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_shared_items_on_assignee_id"
    t.index ["creator_id"], name: "index_shared_items_on_creator_id"
    t.index ["parent_id"], name: "index_shared_items_on_parent_id"
    t.index ["shared_relationship_space_id", "due_at"], name: "index_shared_items_on_space_and_due"
    t.index ["shared_relationship_space_id"], name: "index_shared_items_on_shared_relationship_space_id"
    t.check_constraint "editing::text = ANY (ARRAY['creator'::character varying, 'participants'::character varying]::text[])", name: "shared_item_editing"
    t.check_constraint "kind::text = ANY (ARRAY['plan'::character varying, 'date'::character varying, 'task'::character varying, 'reminder'::character varying, 'note'::character varying]::text[])", name: "shared_item_kind"
  end

  create_table "shared_relationship_spaces", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "invitation_expires_at", null: false
    t.text "invited_email", null: false
    t.uuid "owner_id", null: false
    t.uuid "partner_id"
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_email"], name: "index_shared_relationship_spaces_on_invited_email"
    t.index ["owner_id"], name: "index_shared_relationship_spaces_on_owner_id"
    t.index ["partner_id"], name: "index_shared_relationship_spaces_on_partner_id"
    t.check_constraint "(partner_id IS NULL) = (accepted_at IS NULL)", name: "shared_space_acceptance_required"
    t.check_constraint "partner_id IS NULL OR partner_id <> owner_id", name: "shared_space_distinct_people"
  end

  create_table "shared_reminder_subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "delivered_for"
    t.uuid "shared_item_id", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["shared_item_id", "user_id"], name: "index_shared_reminder_subscriptions_unique", unique: true
    t.index ["shared_item_id"], name: "index_shared_reminder_subscriptions_on_shared_item_id"
    t.index ["user_id"], name: "index_shared_reminder_subscriptions_on_user_id"
  end

  create_table "social_context_notes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "allow_suggestions", default: false, null: false
    t.datetime "analyzed_at"
    t.datetime "created_at", null: false
    t.text "interpretation"
    t.string "interpretation_status", default: "not_requested", null: false
    t.integer "lock_version", default: 0, null: false
    t.uuid "relationship_profile_id", null: false
    t.jsonb "suggested_uses", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "allow_suggestions"], name: "index_social_context_notes_on_profile_and_suggestion_usage"
    t.index ["relationship_profile_id", "created_at"], name: "idx_on_relationship_profile_id_created_at_71f3ad1154"
    t.index ["relationship_profile_id"], name: "index_social_context_notes_on_relationship_profile_id"
    t.check_constraint "interpretation_status::text = ANY (ARRAY['not_requested'::character varying, 'draft'::character varying, 'approved'::character varying]::text[])", name: "social_context_notes_interpretation_status"
    t.check_constraint "jsonb_typeof(suggested_uses) = 'array'::text", name: "social_context_notes_suggested_uses_array"
  end

  create_table "suggestion_feedbacks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "acted_at"
    t.datetime "created_at", null: false
    t.datetime "dismissed_at"
    t.string "feedback"
    t.string "fingerprint", null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "saved_at"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["relationship_profile_id", "dismissed_at"], name: "idx_on_relationship_profile_id_dismissed_at_d046df9002"
    t.index ["relationship_profile_id"], name: "index_suggestion_feedbacks_on_relationship_profile_id"
    t.index ["user_id", "fingerprint"], name: "index_suggestion_feedbacks_on_user_id_and_fingerprint", unique: true
    t.index ["user_id"], name: "index_suggestion_feedbacks_on_user_id"
    t.check_constraint "feedback IS NULL OR (feedback::text = ANY (ARRAY['helpful'::character varying, 'not_for_me'::character varying]::text[]))", name: "suggestion_feedbacks_supported_feedback"
  end

  create_table "template_fields", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "field_type", default: "text", null: false
    t.string "key", null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.text "prompt"
    t.uuid "relationship_template_id", null: false
    t.boolean "required", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_template_id", "active", "position"], name: "idx_on_relationship_template_id_active_position_5de85f3010"
    t.index ["relationship_template_id", "key"], name: "index_template_fields_on_relationship_template_id_and_key", unique: true
    t.index ["relationship_template_id"], name: "index_template_fields_on_relationship_template_id"
  end

  create_table "timeline_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "entry_type", null: false
    t.datetime "occurred_at", null: false
    t.string "origin", default: "manual", null: false
    t.uuid "relationship_profile_id", null: false
    t.uuid "source_record_id"
    t.string "source_record_type"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_profile_id", "entry_type"], name: "idx_on_relationship_profile_id_entry_type_7a425876dd"
    t.index ["relationship_profile_id", "occurred_at"], name: "idx_on_relationship_profile_id_occurred_at_81b70cd1a8"
    t.index ["relationship_profile_id", "origin"], name: "index_timeline_entries_on_relationship_profile_id_and_origin"
    t.index ["relationship_profile_id"], name: "index_timeline_entries_on_relationship_profile_id"
    t.index ["source_record_type", "source_record_id"], name: "idx_on_source_record_type_source_record_id_f700104f25"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.integer "calendar_connection_generation", default: 0, null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.integer "contacts_connection_generation", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.integer "messaging_connection_generation", default: 0, null: false
    t.datetime "onboarding_completed_at"
    t.datetime "onboarding_skipped_at"
    t.integer "privacy_vault_lease_version", default: 0, null: false
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "uid"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.check_constraint "calendar_connection_generation >= 0", name: "users_calendar_connection_generation_nonnegative"
  end

  create_table "vault_access_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.uuid "privacy_vault_item_id"
    t.uuid "relationship_profile_id"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["privacy_vault_item_id"], name: "index_vault_access_events_on_privacy_vault_item_id"
    t.index ["relationship_profile_id", "occurred_at"], name: "idx_on_relationship_profile_id_occurred_at_dc7b578e55"
    t.index ["relationship_profile_id"], name: "index_vault_access_events_on_relationship_profile_id"
    t.index ["user_id", "occurred_at"], name: "index_vault_access_events_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_vault_access_events_on_user_id"
    t.check_constraint "event_type::text = ANY (ARRAY['unlock_failed'::character varying, 'unlocked'::character varying, 'locked'::character varying, 'viewed'::character varying, 'protected'::character varying, 'restored'::character varying, 'suggestion_usage_changed'::character varying]::text[])", name: "vault_access_events_supported_event_type"
  end

  create_table "vendor_options", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "constraints"
    t.datetime "created_at", null: false
    t.string "decision", default: "considering", null: false
    t.boolean "favorite", default: false, null: false
    t.integer "lock_version", default: 0, null: false
    t.text "next_action"
    t.text "notes"
    t.datetime "rejected_at"
    t.datetime "selected_at"
    t.datetime "updated_at", null: false
    t.uuid "vendor_id", null: false
    t.uuid "vendor_shortlist_id", null: false
    t.index ["vendor_id"], name: "index_vendor_options_on_vendor_id"
    t.index ["vendor_shortlist_id", "vendor_id"], name: "index_vendor_options_on_vendor_shortlist_id_and_vendor_id", unique: true
    t.index ["vendor_shortlist_id"], name: "index_vendor_options_on_one_selected_per_shortlist", unique: true, where: "((decision)::text = 'selected'::text)"
    t.index ["vendor_shortlist_id"], name: "index_vendor_options_on_vendor_shortlist_id"
    t.check_constraint "decision::text = ANY (ARRAY['considering'::character varying, 'rejected'::character varying, 'selected'::character varying]::text[])", name: "vendor_options_decision_check"
  end

  create_table "vendor_quotes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.date "decision_due_on"
    t.uuid "event_plan_id", null: false
    t.date "expires_on"
    t.integer "lock_version", default: 0, null: false
    t.text "next_action"
    t.text "notes"
    t.text "scope_details", null: false
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.uuid "vendor_id", null: false
    t.index ["event_plan_id", "status", "expires_on"], name: "index_vendor_quotes_on_plan_status_and_expiration"
    t.index ["event_plan_id"], name: "index_vendor_quotes_on_event_plan_id"
    t.index ["user_id", "created_at"], name: "index_vendor_quotes_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_vendor_quotes_on_user_id"
    t.index ["vendor_id"], name: "index_vendor_quotes_on_vendor_id"
    t.check_constraint "amount_cents >= 0", name: "vendor_quotes_amount_nonnegative"
    t.check_constraint "currency::text ~ '^[A-Z]{3}$'::text", name: "vendor_quotes_currency_format"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'awaiting_response'::character varying, 'received'::character varying, 'under_review'::character varying, 'accepted'::character varying, 'declined'::character varying, 'expired'::character varying]::text[])", name: "vendor_quotes_supported_status"
  end

  create_table "vendor_shortlists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "event_plan_id"
    t.integer "lock_version", default: 0, null: false
    t.uuid "relationship_profile_id", null: false
    t.text "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["event_plan_id"], name: "index_vendor_shortlists_on_event_plan_id"
    t.index ["relationship_profile_id", "created_at"], name: "index_vendor_shortlists_on_profile_and_created_at"
    t.index ["relationship_profile_id"], name: "index_vendor_shortlists_on_relationship_profile_id"
    t.index ["user_id", "created_at"], name: "index_vendor_shortlists_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_vendor_shortlists_on_user_id"
  end

  create_table "vendors", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "availability"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "fit_notes"
    t.string "location"
    t.uuid "marketplace_listing_id"
    t.integer "maximum_price_cents"
    t.integer "minimum_price_cents"
    t.string "name", null: false
    t.jsonb "occasion_types", default: [], null: false
    t.jsonb "preference_tags", default: [], null: false
    t.string "source_kind", default: "manual", null: false
    t.string "source_name"
    t.string "source_url"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_vendors_on_user_and_lower_name"
    t.index ["marketplace_listing_id"], name: "index_vendors_on_marketplace_listing_id"
    t.index ["occasion_types"], name: "index_vendors_on_occasion_types", using: :gin
    t.index ["preference_tags"], name: "index_vendors_on_preference_tags", using: :gin
    t.index ["user_id", "category"], name: "index_vendors_on_user_id_and_category"
    t.index ["user_id", "marketplace_listing_id"], name: "index_vendors_on_owner_and_marketplace_listing", unique: true, where: "(marketplace_listing_id IS NOT NULL)"
    t.index ["user_id"], name: "index_vendors_on_user_id"
    t.check_constraint "maximum_price_cents IS NULL OR maximum_price_cents >= 0", name: "vendors_maximum_price_nonnegative"
    t.check_constraint "minimum_price_cents IS NULL OR maximum_price_cents IS NULL OR minimum_price_cents <= maximum_price_cents", name: "vendors_price_range_ordered"
    t.check_constraint "minimum_price_cents IS NULL OR minimum_price_cents >= 0", name: "vendors_minimum_price_nonnegative"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_blobs", "users", column: "uploaded_by_user_id", on_delete: :nullify
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "approval_decisions", "approval_requests", on_delete: :cascade
  add_foreign_key "approval_decisions", "users", on_delete: :cascade
  add_foreign_key "approval_requests", "users", on_delete: :cascade
  add_foreign_key "audit_events", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "audit_events", "users", on_delete: :cascade
  add_foreign_key "automation_permission_changes", "users"
  add_foreign_key "automation_permission_changes", "users", column: "actor_id"
  add_foreign_key "automation_permissions", "relationship_profiles"
  add_foreign_key "automation_permissions", "users"
  add_foreign_key "backup_options", "backup_plans", on_delete: :cascade
  add_foreign_key "backup_plans", "event_plans", on_delete: :cascade
  add_foreign_key "backup_plans", "users", on_delete: :cascade
  add_foreign_key "bookings", "event_plans", on_delete: :cascade
  add_foreign_key "bookings", "plan_tasks", on_delete: :nullify
  add_foreign_key "bookings", "users", on_delete: :cascade
  add_foreign_key "calendar_connections", "users", on_delete: :cascade
  add_foreign_key "calendar_credential_revocations", "users", on_delete: :cascade
  add_foreign_key "calendar_event_syncs", "calendar_connections", on_delete: :cascade
  add_foreign_key "commitments", "relationship_profiles", on_delete: :cascade
  add_foreign_key "contact_cadences", "relationship_profiles", on_delete: :cascade
  add_foreign_key "contact_methods", "relationship_profiles"
  add_foreign_key "contacts_connections", "users"
  add_foreign_key "conversation_recaps", "relationship_profiles"
  add_foreign_key "deletion_requests", "users", on_delete: :nullify
  add_foreign_key "desire_fulfillments", "desires"
  add_foreign_key "desires", "relationship_profiles"
  add_foreign_key "digest_deliveries", "users"
  add_foreign_key "draft_revisions", "message_drafts", on_delete: :cascade
  add_foreign_key "event_plan_vendors", "event_plans", on_delete: :cascade
  add_foreign_key "event_plan_vendors", "vendors", on_delete: :cascade
  add_foreign_key "event_plans", "relationship_profiles", on_delete: :cascade
  add_foreign_key "event_plans", "users", on_delete: :cascade
  add_foreign_key "external_provider_actions", "bookings", on_delete: :cascade
  add_foreign_key "external_provider_actions", "event_plans", on_delete: :cascade
  add_foreign_key "external_provider_actions", "gift_purchase_plans", on_delete: :cascade
  add_foreign_key "external_provider_actions", "relationship_profiles", on_delete: :cascade
  add_foreign_key "external_provider_actions", "reminders", on_delete: :cascade
  add_foreign_key "external_provider_actions", "users", on_delete: :cascade
  add_foreign_key "external_provider_actions", "vendor_quotes", on_delete: :cascade
  add_foreign_key "extracted_memories", "conversation_recaps", on_delete: :cascade
  add_foreign_key "extracted_memories", "memory_records", column: "canonical_memory_record_id", on_delete: :nullify
  add_foreign_key "extracted_memories", "relationship_profiles", on_delete: :cascade
  add_foreign_key "extracted_memories", "users", column: "reviewed_by_id", on_delete: :nullify
  add_foreign_key "feature_flag_assignments", "feature_flags"
  add_foreign_key "feature_flag_audit_events", "feature_flags"
  add_foreign_key "feature_flag_audit_events", "users", column: "actor_id"
  add_foreign_key "feed_item_states", "users", on_delete: :cascade
  add_foreign_key "gift_purchase_plans", "gifts", on_delete: :cascade
  add_foreign_key "gift_purchase_plans", "plan_tasks", on_delete: :nullify
  add_foreign_key "gift_recommendations", "gifts", on_delete: :nullify
  add_foreign_key "gift_recommendations", "relationship_profiles", on_delete: :cascade
  add_foreign_key "gift_recommendations", "users", on_delete: :cascade
  add_foreign_key "gift_box_items", "gift_boxes", on_delete: :cascade
  add_foreign_key "gift_boxes", "relationship_profiles", on_delete: :cascade
  add_foreign_key "gifts", "relationship_profiles"
  add_foreign_key "important_dates", "relationship_profiles"
  add_foreign_key "imported_contacts", "contacts_connections"
  add_foreign_key "imported_contacts", "relationship_profiles", on_delete: :nullify
  add_foreign_key "imported_message_contexts", "messaging_connections"
  add_foreign_key "interactions", "relationship_profiles", on_delete: :cascade
  add_foreign_key "memory_records", "relationship_profiles"
  add_foreign_key "memory_revisions", "memory_records"
  add_foreign_key "memory_revisions", "users"
  add_foreign_key "message_drafts", "relationship_profiles", on_delete: :cascade
  add_foreign_key "message_drafts", "users", on_delete: :cascade
  add_foreign_key "messaging_connections", "users"
  add_foreign_key "mood_notes", "relationship_profiles"
  add_foreign_key "notification_preferences", "users", on_delete: :cascade
  add_foreign_key "personal_touch_checklists", "event_plans", on_delete: :cascade
  add_foreign_key "personal_touch_checklists", "important_dates", on_delete: :cascade
  add_foreign_key "personal_touch_checklists", "relationship_profiles", on_delete: :cascade
  add_foreign_key "personal_touch_items", "personal_touch_checklists", on_delete: :cascade
  add_foreign_key "plan_tasks", "backup_options", on_delete: :nullify
  add_foreign_key "plan_tasks", "event_plans", on_delete: :cascade
  add_foreign_key "privacy_vault_items", "relationship_profiles", on_delete: :cascade
  add_foreign_key "relationship_briefings", "relationship_profiles", on_delete: :cascade
  add_foreign_key "relationship_briefings", "users", on_delete: :cascade
  add_foreign_key "relationship_field_values", "relationship_profiles"
  add_foreign_key "relationship_field_values", "template_fields"
  add_foreign_key "relationship_group_memberships", "relationship_groups", on_delete: :cascade
  add_foreign_key "relationship_group_memberships", "relationship_profiles", on_delete: :cascade
  add_foreign_key "relationship_groups", "users"
  add_foreign_key "relationship_notes", "relationship_profiles"
  add_foreign_key "relationship_notification_preferences", "notification_preferences", on_delete: :cascade
  add_foreign_key "relationship_notification_preferences", "relationship_profiles", on_delete: :cascade
  add_foreign_key "relationship_preferences", "relationship_profiles"
  add_foreign_key "relationship_profiles", "users"
  add_foreign_key "relationship_taggings", "relationship_profiles", on_delete: :cascade
  add_foreign_key "relationship_taggings", "relationship_tags", on_delete: :cascade
  add_foreign_key "relationship_tags", "users"
  add_foreign_key "reminder_deliveries", "noticed_events", on_delete: :nullify
  add_foreign_key "reminder_deliveries", "reminders", on_delete: :cascade
  add_foreign_key "reminders", "bookings", on_delete: :nullify
  add_foreign_key "reminders", "commitments", on_delete: :cascade
  add_foreign_key "reminders", "event_plans", on_delete: :cascade
  add_foreign_key "reminders", "important_dates", on_delete: :nullify
  add_foreign_key "reminders", "plan_tasks", on_delete: :nullify
  add_foreign_key "reminders", "relationship_profiles", on_delete: :cascade
  add_foreign_key "reminders", "users", on_delete: :cascade
  add_foreign_key "reminders", "vendor_quotes", on_delete: :nullify
  add_foreign_key "shared_items", "shared_items", column: "parent_id", on_delete: :nullify
  add_foreign_key "shared_items", "shared_relationship_spaces", on_delete: :cascade
  add_foreign_key "shared_items", "users", column: "assignee_id", on_delete: :nullify
  add_foreign_key "shared_items", "users", column: "creator_id", on_delete: :cascade
  add_foreign_key "shared_relationship_spaces", "users", column: "owner_id", on_delete: :cascade
  add_foreign_key "shared_relationship_spaces", "users", column: "partner_id", on_delete: :cascade
  add_foreign_key "shared_reminder_subscriptions", "shared_items", on_delete: :cascade
  add_foreign_key "shared_reminder_subscriptions", "users", on_delete: :cascade
  add_foreign_key "social_context_notes", "relationship_profiles", on_delete: :cascade
  add_foreign_key "suggestion_feedbacks", "relationship_profiles", on_delete: :cascade
  add_foreign_key "suggestion_feedbacks", "users", on_delete: :cascade
  add_foreign_key "template_fields", "relationship_templates"
  add_foreign_key "timeline_entries", "relationship_profiles"
  add_foreign_key "vault_access_events", "privacy_vault_items", on_delete: :nullify
  add_foreign_key "vault_access_events", "relationship_profiles", on_delete: :nullify
  add_foreign_key "vault_access_events", "users", on_delete: :cascade
  add_foreign_key "vendor_options", "vendor_shortlists", on_delete: :cascade
  add_foreign_key "vendor_options", "vendors"
  add_foreign_key "vendor_quotes", "event_plans", on_delete: :cascade
  add_foreign_key "vendor_quotes", "users", on_delete: :cascade
  add_foreign_key "vendor_quotes", "vendors"
  add_foreign_key "vendor_shortlists", "event_plans", on_delete: :cascade
  add_foreign_key "vendor_shortlists", "relationship_profiles", on_delete: :cascade
  add_foreign_key "vendor_shortlists", "users", on_delete: :cascade
  add_foreign_key "vendors", "marketplace_listings", on_delete: :nullify
  add_foreign_key "vendors", "users", on_delete: :cascade
end
