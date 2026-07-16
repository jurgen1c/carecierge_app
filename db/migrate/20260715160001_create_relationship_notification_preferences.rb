class CreateRelationshipNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :relationship_notification_preferences, id: :uuid do |t|
      t.references :notification_preference, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :relationship_profile, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.string :mode, null: false, default: "muted"

      t.timestamps
    end

    add_check_constraint :relationship_notification_preferences,
      "mode IN ('muted')",
      name: "relationship_notification_preferences_supported_mode"
  end
end
