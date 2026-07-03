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

ActiveRecord::Schema[8.1].define(version: 2026_07_01_025353) do
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
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index "relationship_profile_id, lower((key)::text)", name: "idx_relationship_preferences_on_profile_and_lower_key", unique: true
    t.index ["relationship_profile_id"], name: "index_relationship_preferences_on_relationship_profile_id"
  end

  create_table "relationship_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.date "birthday"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "first_name", null: false
    t.string "last_name"
    t.string "preferred_name"
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

  create_table "relationship_tags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "relationship_profile_id", null: false
    t.datetime "updated_at", null: false
    t.index "relationship_profile_id, lower((name)::text)", name: "index_relationship_tags_on_profile_id_and_lower_name", unique: true
    t.index ["relationship_profile_id"], name: "index_relationship_tags_on_relationship_profile_id"
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
  add_foreign_key "contact_methods", "relationship_profiles"
  add_foreign_key "feature_flag_assignments", "feature_flags"
  add_foreign_key "feature_flag_audit_events", "feature_flags"
  add_foreign_key "feature_flag_audit_events", "users", column: "actor_id"
  add_foreign_key "relationship_field_values", "relationship_profiles"
  add_foreign_key "relationship_field_values", "template_fields"
  add_foreign_key "relationship_notes", "relationship_profiles"
  add_foreign_key "relationship_preferences", "relationship_profiles"
  add_foreign_key "relationship_profiles", "users"
  add_foreign_key "relationship_tags", "relationship_profiles"
  add_foreign_key "template_fields", "relationship_templates"
end
