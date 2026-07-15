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

ActiveRecord::Schema[8.1].define(version: 2026_07_15_032726) do
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
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
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

  create_table "conversation_recaps", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.string "capture_source", default: "typed", null: false
    t.datetime "created_at", null: false
    t.datetime "extraction_approved_at"
    t.datetime "extraction_requested_at"
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
    t.boolean "email_enabled", default: true, null: false
    t.boolean "in_app_enabled", default: true, null: false
    t.boolean "push_enabled", default: false, null: false
    t.boolean "sms_enabled", default: false, null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_notification_preferences_on_user_id", unique: true
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
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "first_name", null: false
    t.string "last_name"
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
    t.uuid "commitment_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.uuid "important_date_id"
    t.datetime "next_delivery_at"
    t.text "notes"
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
    t.index ["commitment_id"], name: "index_reminders_on_commitment_id"
    t.index ["important_date_id"], name: "index_reminders_on_important_date_id"
    t.index ["next_delivery_at"], name: "index_reminders_on_active_next_delivery_at", where: "(((status)::text = 'active'::text) AND (next_delivery_at IS NOT NULL))"
    t.index ["relationship_profile_id", "status", "scheduled_at"], name: "index_reminders_on_profile_status_and_schedule"
    t.index ["relationship_profile_id"], name: "index_reminders_on_relationship_profile_id"
    t.index ["user_id", "status", "scheduled_at"], name: "index_reminders_on_user_id_and_status_and_scheduled_at"
    t.index ["user_id"], name: "index_reminders_on_user_id"
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
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.datetime "locked_at"
    t.datetime "onboarding_completed_at"
    t.datetime "onboarding_skipped_at"
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
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "commitments", "relationship_profiles", on_delete: :cascade
  add_foreign_key "contact_cadences", "relationship_profiles", on_delete: :cascade
  add_foreign_key "contact_methods", "relationship_profiles"
  add_foreign_key "conversation_recaps", "relationship_profiles"
  add_foreign_key "desire_fulfillments", "desires"
  add_foreign_key "desires", "relationship_profiles"
  add_foreign_key "feature_flag_assignments", "feature_flags"
  add_foreign_key "feature_flag_audit_events", "feature_flags"
  add_foreign_key "feature_flag_audit_events", "users", column: "actor_id"
  add_foreign_key "gifts", "relationship_profiles"
  add_foreign_key "important_dates", "relationship_profiles"
  add_foreign_key "interactions", "relationship_profiles", on_delete: :cascade
  add_foreign_key "memory_records", "relationship_profiles"
  add_foreign_key "memory_revisions", "memory_records"
  add_foreign_key "memory_revisions", "users"
  add_foreign_key "mood_notes", "relationship_profiles"
  add_foreign_key "notification_preferences", "users", on_delete: :cascade
  add_foreign_key "relationship_field_values", "relationship_profiles"
  add_foreign_key "relationship_field_values", "template_fields"
  add_foreign_key "relationship_group_memberships", "relationship_groups", on_delete: :cascade
  add_foreign_key "relationship_group_memberships", "relationship_profiles", on_delete: :cascade
  add_foreign_key "relationship_groups", "users"
  add_foreign_key "relationship_notes", "relationship_profiles"
  add_foreign_key "relationship_preferences", "relationship_profiles"
  add_foreign_key "relationship_profiles", "users"
  add_foreign_key "relationship_taggings", "relationship_profiles", on_delete: :cascade
  add_foreign_key "relationship_taggings", "relationship_tags", on_delete: :cascade
  add_foreign_key "relationship_tags", "users"
  add_foreign_key "reminder_deliveries", "noticed_events", on_delete: :nullify
  add_foreign_key "reminder_deliveries", "reminders", on_delete: :cascade
  add_foreign_key "reminders", "commitments", on_delete: :cascade
  add_foreign_key "reminders", "important_dates", on_delete: :nullify
  add_foreign_key "reminders", "relationship_profiles", on_delete: :cascade
  add_foreign_key "reminders", "users", on_delete: :cascade
  add_foreign_key "template_fields", "relationship_templates"
  add_foreign_key "timeline_entries", "relationship_profiles"
end
