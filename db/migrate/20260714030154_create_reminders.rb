class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders, id: :uuid do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :relationship_profile, null: true, foreign_key: { on_delete: :cascade }, type: :uuid
      t.references :important_date, null: true, foreign_key: { on_delete: :nullify }, type: :uuid
      t.string :title, null: false
      t.text :notes
      t.string :reminder_type, null: false, default: "custom"
      t.string :priority, null: false, default: "normal"
      t.string :recurrence, null: false, default: "none"
      t.datetime :recurrence_anchor_at, null: false
      t.string :time_zone, null: false, default: "UTC"
      t.string :status, null: false, default: "active"
      t.datetime :scheduled_at, null: false
      t.datetime :next_delivery_at
      t.datetime :snoozed_until
      t.datetime :completed_at

      t.timestamps
    end

    add_index :reminders, [ :user_id, :status, :scheduled_at ]
    add_index :reminders, :next_delivery_at,
      where: "status = 'active' AND next_delivery_at IS NOT NULL",
      name: "index_reminders_on_active_next_delivery_at"
    add_index :reminders, [ :relationship_profile_id, :status, :scheduled_at ], name: "index_reminders_on_profile_status_and_schedule"
  end
end
