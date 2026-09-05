module Messaging
  class DeleteContext
    def self.call(user:, context_id:)
      user.with_lock("FOR NO KEY UPDATE") do
        connection = MessagingConnection.find_by!(user_id: user.id)
        connection.imported_message_contexts.find(context_id).destroy!
        AuditEvent.record!(user:, actor: user, action: "messaging.context.deleted", target: user, metadata: { result: "deleted" })
      end
    end
  end
end
