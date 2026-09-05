class CreateCalendarConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_connections, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :provider, null: false, default: "google_calendar"
      t.text :access_token, null: false
      t.text :refresh_token, null: false
      t.datetime :token_expires_at, null: false
      t.string :granted_scopes, array: true, null: false, default: []
      t.string :sync_types, array: true, null: false, default: []
      t.string :sync_status, null: false, default: "connected"
      t.datetime :last_sync_started_at
      t.datetime :last_synced_at
      t.datetime :last_error_at
      t.string :last_error_code
      t.integer :lock_version, null: false, default: 0
      t.timestamps

      t.check_constraint "provider IN ('google_calendar')", name: "calendar_connections_supported_provider"
      t.check_constraint "sync_status IN ('connected', 'syncing', 'failed', 'action_required')",
        name: "calendar_connections_supported_status"
    end

    create_table :calendar_event_syncs, id: :uuid do |t|
      t.references :calendar_connection, null: false, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :source_type, null: false
      t.uuid :source_id, null: false
      t.text :external_event_id, null: false
      t.string :source_fingerprint, null: false
      t.datetime :synced_at
      t.timestamps

      t.index [ :calendar_connection_id, :source_type, :source_id ],
        unique: true,
        name: "index_calendar_event_synces_on_connection_and_source"
    end
  end
end
