module Contacts
  class Connect
    def self.call(user:, code:, redirect_uri:, generation:)
      error = nil
      connection = nil
      user.with_lock("FOR NO KEY UPDATE") do
        raise Error.new(code: "stale") unless user.contacts_connection_generation == generation
        raise Error.new(code: "already_connected") if user.contacts_connection
        Permission.check!(user:)
        credentials = nil
        begin
          credentials = GoogleOauth.exchange(code:, redirect_uri:)
          ContactsConnection.transaction(requires_new: true) do
            connection = user.create_contacts_connection!(access_token: credentials.access_token,
              refresh_token: credentials.refresh_token, token_expires_at: credentials.expires_at)
            user.increment!(:contacts_connection_generation)
            AuditEvent.record!(user:, actor: user, action: "contacts.connection.created", target: user, metadata: { result: "success" })
          end
        rescue StandardError => failure
          error = failure
          credentials ||= failure.credentials if failure.respond_to?(:credentials)
          user.reload
          cleanup!(user:, credentials:) if credentials && (credentials.access_token.present? || credentials.refresh_token.present?)
        end
      end
      raise error if error
      connection
    end

    def self.cleanup!(user:, credentials:)
      GoogleOauth.revoke(credentials:)
    rescue Error
      user.create_contacts_connection!(status: "cleanup_required", access_token: credentials.access_token,
        refresh_token: credentials.refresh_token, token_expires_at: credentials.expires_at)
      user.increment!(:contacts_connection_generation)
    end
    private_class_method :cleanup!
  end
end
