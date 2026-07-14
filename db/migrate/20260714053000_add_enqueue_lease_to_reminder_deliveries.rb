class AddEnqueueLeaseToReminderDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :reminder_deliveries, :enqueued_at, :datetime
    add_index :reminder_deliveries, :enqueued_at,
      where: "status = 'pending'",
      name: "index_reminder_deliveries_on_pending_enqueue_lease"
  end
end
