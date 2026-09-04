class AddCalendarSyncLeases < ActiveRecord::Migration[8.1]
  def change
    add_column :calendar_connections, :sync_lease_token, :uuid
    add_column :calendar_connections, :sync_lease_expires_at, :datetime
    add_column :calendar_connections, :resync_requested, :boolean, null: false, default: false
    add_index :calendar_connections, [ :sync_status, :sync_lease_expires_at ], name: "index_calendar_connections_on_sync_lease"
    add_check_constraint :calendar_connections,
      <<~SQL.squish,
        (sync_status = 'syncing' AND sync_lease_token IS NOT NULL AND sync_lease_expires_at IS NOT NULL)
        OR
        (sync_status <> 'syncing' AND sync_lease_token IS NULL AND sync_lease_expires_at IS NULL)
      SQL
      name: "calendar_connections_complete_sync_lease"
  end
end
