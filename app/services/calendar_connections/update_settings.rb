module CalendarConnections
  class UpdateSettings
    def self.call(connection:, sync_types:, actor:)
      enqueue_sync = false
      normalized_sync_types = normalize_sync_types(sync_types)
      connection.user.with_lock("FOR NO KEY UPDATE") do
        connection.with_lock do
          changed = normalize_sync_types(connection.sync_types) != normalized_sync_types
          connection.assign_attributes(sync_types: normalized_sync_types)
          if changed
            if connection.actively_syncing?
              connection.resync_requested = true
            else
              enqueue_sync = true
            end
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

    def self.normalize_sync_types(sync_types)
      Array(sync_types).map(&:to_s).sort_by do |sync_type|
        [ CalendarConnection::SYNC_TYPES.index(sync_type) || CalendarConnection::SYNC_TYPES.length, sync_type ]
      end
    end
    private_class_method :normalize_sync_types
  end
end
