module AuditEvents
  class Track
    def self.call(
      user:,
      actor:,
      action:,
      target:,
      source: "web_app",
      actor_kind: nil,
      metadata: {},
      record_if: true,
      &mutation
    )
      ApplicationRecord.transaction do
        result = mutation.call
        if result && record_if
          AuditEvent.record!(
            user:,
            actor:,
            actor_kind:,
            action:,
            source:,
            target:,
            metadata:
          )
        end
        result
      end
    end
  end
end
