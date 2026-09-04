class HardenCalendarConnections < ActiveRecord::Migration[8.1]
  OLD_INDEX = "index_calendar_event_synces_on_connection_and_source"
  NEW_INDEX = "index_calendar_event_syncs_on_connection_and_source"

  def up
    rename_index :calendar_event_syncs, OLD_INDEX, NEW_INDEX if index_name_exists?(:calendar_event_syncs, OLD_INDEX)
    add_check_constraint :calendar_connections,
      "sync_types <@ ARRAY['important_dates', 'reminders', 'event_plans', 'bookings', 'commitments']::varchar[]",
      name: "calendar_connections_supported_sync_types"
    add_check_constraint :calendar_connections,
      "'https://www.googleapis.com/auth/calendar.events.owned' = ANY(granted_scopes)",
      name: "calendar_connections_required_google_scope"
  end

  def down
    remove_check_constraint :calendar_connections, name: "calendar_connections_required_google_scope"
    remove_check_constraint :calendar_connections, name: "calendar_connections_supported_sync_types"
    rename_index :calendar_event_syncs, NEW_INDEX, OLD_INDEX if index_name_exists?(:calendar_event_syncs, NEW_INDEX)
  end
end
