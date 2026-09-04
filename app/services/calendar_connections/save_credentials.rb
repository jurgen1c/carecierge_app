module CalendarConnections
  class SaveCredentials
    def self.call(user:, credentials:, actor:, expected_generation:, locale: I18n.locale, after_previous_revoke: nil)
      new(
        user:,
        credentials:,
        actor:,
        expected_generation:,
        locale:,
        after_previous_revoke:
      ).call
    end

    def initialize(user:, credentials:, actor:, expected_generation:, locale:, after_previous_revoke:)
      @user = user
      @credentials = credentials
      @actor = actor
      @expected_generation = expected_generation
      @locale = locale
      @after_previous_revoke = after_previous_revoke
    end

    def call
      connection = nil
      user.with_lock do
        unless user.calendar_connection_generation == expected_generation
          raise ConnectionError.new(code: "stale_authorization")
        end
        raise ConnectionError.new(code: "revocation_failed") if user.calendar_credential_revocations.exists?

        connection = user.calendar_connection || user.build_calendar_connection
        if connection.persisted? && connection.last_error_code == "revocation_failed"
          raise ConnectionError.new(code: "revocation_failed")
        end

        replacing_credentials = connection.persisted?
        revoke_previous_credentials!(connection) if replacing_credentials
        connection.assign_attributes(
          provider: "google_calendar",
          locale: locale.to_s,
          access_token: credentials.access_token,
          refresh_token: credentials.refresh_token,
          token_expires_at: credentials.expires_at,
          granted_scopes: credentials.scopes,
          sync_status: "connected",
          sync_lease_token: nil,
          sync_lease_expires_at: nil,
          resync_requested: false,
          last_error_at: nil,
          last_error_code: nil
        )
        connection.save!
        connection.calendar_event_syncs.update_all(synced_at: nil) if replacing_credentials
        AuditEvent.record!(
          user:,
          actor:,
          action: "calendar.connection.created",
          target: connection,
          metadata: { result: "success" }
        )
        user.increment!(:calendar_connection_generation)
      end
      connection
    end

    private

    attr_reader :actor, :after_previous_revoke, :credentials, :expected_generation, :locale, :user

    def revoke_previous_credentials!(connection)
      CalendarProviders::Google.new(connection:).revoke
      after_previous_revoke&.call
    rescue CalendarProviders::Error
      raise ConnectionError.new(code: "revocation_failed", previous_revocation_failed: true)
    end
  end
end
