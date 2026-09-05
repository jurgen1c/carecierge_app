class AddPendingAuditCountToCalendarConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :calendar_connections, :pending_audit_count, :integer, null: false, default: 0
    add_check_constraint :calendar_connections, "pending_audit_count >= 0",
      name: "calendar_connections_nonnegative_pending_audit_count"
  end
end
