module Messaging
  class Import
    def self.call(user:, external_id:, approved:, provider: nil)
      raise Error.new(code: "permission_required") unless approved == true
      Access.call(user:) do |connection|
        data = (provider || Google.new(connection:)).message(external_id:)
        key = Digest::SHA256.hexdigest(data.fetch(:external_id))
        existing = connection.imported_message_contexts.find_by(source_key: key)
        next existing if existing
        context = connection.imported_message_contexts.create!(**data, source_key: key)
        AuditEvent.record!(user:, actor: user, action: "messaging.context.imported", target: user, metadata: { result: "imported" })
        context
      end
    end
  end
end
