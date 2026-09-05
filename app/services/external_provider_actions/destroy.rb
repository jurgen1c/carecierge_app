module ExternalProviderActions
  class Destroy
    def self.call(record, actor:)
      raise Pundit::NotAuthorizedError unless actor && actor.id == record.user_id

      record.user.with_lock("FOR NO KEY UPDATE") do
        record.relationship_profile.with_lock do
          record.lock!
          record.destroy!
          AuditEvent.record!(user: record.user, actor:, target: record.relationship_profile,
            action: "provider_record.deleted", metadata: { result: "success" })
        end
      end
    end
  end
end
