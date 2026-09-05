module Messaging
  class Draft
    def self.call(user:, context_id:, approved:, expected_version:, generator: MessageDrafts::OpenAiGenerator.new)
      raise Error.new(code: "permission_required") unless approved == true
      user.with_lock("FOR NO KEY UPDATE") do
        Permission.check!(user:, capability: "draft_messages")
        context = MessagingConnection.find_by!(user_id: user.id).imported_message_contexts.lock.find(context_id)
        raise Error.new(code: "stale") unless expected_version.to_s == context.lock_version.to_s
        content = generator.generate(draft_type: "professional_follow_up", tone: "warm",
          situation: context.snippet, response_length: "medium", formality: "balanced", context: "", locale: I18n.locale)
        context.update!(reply_draft: content, reply_ai_generated: true)
        AuditEvent.record!(user:, actor: user, action: "messaging.draft.generated", target: user, metadata: { result: "review_required" })
        context
      end
    end
  end
end
