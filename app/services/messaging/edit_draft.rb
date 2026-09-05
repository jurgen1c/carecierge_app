module Messaging
  class EditDraft
    def self.call(user:, context_id:, content:, expected_version:)
      user.with_lock("FOR NO KEY UPDATE") do
        context = MessagingConnection.find_by!(user_id: user.id).imported_message_contexts.lock.find(context_id)
        raise Error.new(code: "stale") unless expected_version.to_s == context.lock_version.to_s
        context.update!(reply_draft: content.to_s.strip.presence)
        AuditEvent.record!(user:, actor: user, action: "messaging.draft.edited", target: user, metadata: { result: "saved" })
      end
    end
  end
end
