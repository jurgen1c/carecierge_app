module ExternalProviderActions
  class Save
    def self.call(record, actor:, attributes:, expected_lock_version: nil)
      raise Pundit::NotAuthorizedError unless actor && actor.id == record.user_id

      record.user.with_lock("FOR NO KEY UPDATE") do
        record.relationship_profile.with_lock do
          raise ActiveRecord::RecordNotFound unless record.mutable?

          creating = record.new_record?
          unless creating
            record.lock!
            if expected_lock_version != record.lock_version
              raise ActiveRecord::StaleObjectError.new(record, "update")
            end
          end
          record.assign_attributes(attributes)
          record.recorded_at = Time.current
          record.save!
          AuditEvent.record!(user: record.user, actor:, target: record.relationship_profile,
            action: creating ? "provider_record.created" : "provider_record.updated",
            metadata: { result: record.status })
        end
      end
      record
    end
  end
end
