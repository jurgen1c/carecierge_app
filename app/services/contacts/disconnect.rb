module Contacts
  class Disconnect
    def self.call(user:, after_revoke: nil)
      succeeded = true
      failure = nil
      user.with_lock("FOR NO KEY UPDATE") do
        user.increment!(:contacts_connection_generation)
        connection = ContactsConnection.lock.find_by(user_id: user.id)
        if connection
          revoked = false
          begin
            ContactsConnection.transaction(requires_new: true) do
              GoogleOauth.revoke(credentials: connection.credentials)
              revoked = true
              after_revoke&.call
              connection.destroy!
              AuditEvent.record!(user:, actor: user, action: "contacts.connection.revoked", target: user, metadata: { result: "success" })
            end
          rescue StandardError => error
            connection.reload.update!(status: revoked ? "authorization_required" : "cleanup_required")
            succeeded = false
            failure = error unless error.is_a?(Error)
          end
        end
      end
      raise failure if failure
      succeeded
    end
  end
end
