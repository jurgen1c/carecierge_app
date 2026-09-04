module CalendarConnections
  class UpdateSettings
    def self.call(connection:, sync_types:, actor:)
      enqueue_sync = false
      connection.user.with_lock("FOR NO KEY UPDATE") do
        connection.with_lock do
          changed = connection.sync_types != sync_types
          connection.assign_attributes(sync_types:)
          if connection.actively_syncing?
            connection.resync_requested = true
          else
            enqueue_sync = true
          end
          connection.save!
          if changed
            AuditEvent.record!(
              user: connection.user,
              actor:,
              action: "calendar.settings.updated",
              target: connection,
              metadata: { changed_fields: "sync_types" }
            )
          end
        end
      end
      CalendarSyncJob.perform_later(connection, owner_requested: true) if enqueue_sync
      connection
    end
  end
end
