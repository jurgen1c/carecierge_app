class AddReminderDeliveryProcessingFence < ActiveRecord::Migration[8.1]
  def up
    add_column :reminder_deliveries, :lease_token, :uuid
    add_reference :reminder_deliveries, :noticed_event,
      type: :uuid,
      index: { unique: true },
      foreign_key: { to_table: :noticed_events, on_delete: :nullify }
    if index_exists?(:reminder_deliveries, name: "index_reminder_deliveries_on_pending_enqueue_lease")
      remove_index :reminder_deliveries, name: "index_reminder_deliveries_on_pending_enqueue_lease"
    end
    unless index_exists?(:reminder_deliveries, name: "index_reminder_deliveries_on_recoverable_lease")
      add_index :reminder_deliveries, :enqueued_at,
        where: "status IN ('pending', 'dispatching')",
        name: "index_reminder_deliveries_on_recoverable_lease"
    end
  end

  def down
    if index_exists?(:reminder_deliveries, name: "index_reminder_deliveries_on_recoverable_lease")
      remove_index :reminder_deliveries, name: "index_reminder_deliveries_on_recoverable_lease"
    end
    unless index_exists?(:reminder_deliveries, name: "index_reminder_deliveries_on_pending_enqueue_lease")
      add_index :reminder_deliveries, :enqueued_at,
        where: "status = 'pending'",
        name: "index_reminder_deliveries_on_pending_enqueue_lease"
    end
    remove_reference :reminder_deliveries, :noticed_event, foreign_key: true
    remove_column :reminder_deliveries, :lease_token, :uuid
  end
end
