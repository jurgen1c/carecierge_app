module CalendarConnections
  class Disconnect
    def self.call(connection:, actor:, after_revoke: nil)
      new(connection:, actor:, after_revoke:).call
    end

    def initialize(connection:, actor:, after_revoke:)
      @connection = connection
      @actor = actor
      @after_revoke = after_revoke
      @provider_revoked = false
    end

    def call
      succeeded = false
      disconnect_error = nil
      user = connection.user
      user.with_lock do
        begin
          succeeded = CalendarConnection.transaction(requires_new: true) do
            connection.lock!
            disconnect_under_lock(user)
          end
        rescue StandardError => error
          record_completed_revocation!(user:) if provider_revoked? && after_revoke.nil?
          disconnect_error = error
        end
      end
      raise disconnect_error if disconnect_error

      succeeded
    end

    private

    attr_reader :actor, :after_revoke, :connection

    def provider_revoked? = @provider_revoked

    def disconnect_under_lock(user)
      CalendarProviders::Google.new(connection:).revoke
      @provider_revoked = true
      after_revoke&.call
      flush_pending_audit!
      user.increment!(:calendar_connection_generation)
      connection.destroy!
      AuditEvent.record!(
        user:,
        actor:,
        action: "calendar.connection.revoked",
        target: user,
        metadata: { result: "success" }
      )
      true
    rescue CalendarProviders::Error
      record_revocation_failure!
      false
    end

    def flush_pending_audit!
      return unless connection.pending_audit_count.positive?

      AuditEvent.record!(
        user: connection.user,
        actor: nil,
        actor_kind: "system",
        source: "system",
        action: "calendar.sync.completed",
        target: connection,
        metadata: { count: connection.pending_audit_count, result: "success" }
      )
      connection.update!(pending_audit_count: 0)
    end

    def record_revocation_failure!
      connection.update!(
        sync_status: "failed",
        sync_lease_token: nil,
        sync_lease_expires_at: nil,
        resync_requested: false,
        last_error_at: Time.current,
        last_error_code: "revocation_failed"
      )
      AuditEvent.record!(
        user: connection.user,
        actor:,
        action: "calendar.connection.revocation_failed",
        target: connection,
        metadata: { result: "revocation_failed" }
      )
    end

    def record_completed_revocation!(user:)
      restored_connection = CalendarConnection.lock.find_by(user_id: user.id)
      return unless restored_connection

      user.increment!(:calendar_connection_generation)
      restored_connection.update!(
        sync_status: "action_required",
        sync_lease_token: nil,
        sync_lease_expires_at: nil,
        resync_requested: false,
        last_error_at: Time.current,
        last_error_code: "authorization_required"
      )
      AuditEvent.record!(
        user:,
        actor: user,
        action: "calendar.connection.revoked",
        target: user,
        metadata: { result: "success" }
      )
    end
  end
end
