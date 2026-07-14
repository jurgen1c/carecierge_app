class CreateReminderDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :reminder_deliveries, id: :uuid do |t|
      t.references :reminder, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
      t.string :channel, null: false
      t.datetime :scheduled_for, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :dispatched_at
      t.datetime :enqueued_at
      t.text :error_message

      t.timestamps
    end

    add_index :reminder_deliveries, [ :reminder_id, :channel, :scheduled_for ], unique: true, name: "index_reminder_deliveries_on_occurrence_and_channel"
    add_index :reminder_deliveries, :enqueued_at,
      where: "status = 'pending'",
      name: "index_reminder_deliveries_on_pending_enqueue_lease"
  end
end
