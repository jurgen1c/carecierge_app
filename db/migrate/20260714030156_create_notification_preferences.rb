class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid, index: { unique: true }
      t.boolean :in_app_enabled, null: false, default: true
      t.boolean :email_enabled, null: false, default: true
      t.boolean :push_enabled, null: false, default: false
      t.boolean :sms_enabled, null: false, default: false

      t.timestamps
    end
  end
end
