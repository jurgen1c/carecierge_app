module MemoryRecords
  class Update
    TRUST_FIELDS = %i[title body source confidence status].freeze

    def self.call(user:, memory_record:, attributes:, correction_note: nil)
      memory_record.relationship_profile.with_lock do
        memory_record.reload
        Pundit.authorize(user, memory_record, :update?)
        attributes = attributes.to_h.symbolize_keys
        previous_body = memory_record.body
        changed = ->(key) { attributes.key?(key) && normalize(key, attributes[key]) != normalize(key, memory_record.public_send(key)) }
        body_corrected = changed.call(:body)
        corrected = changed.call(:title) || body_corrected
        trust_changed = TRUST_FIELDS.any? { |key| changed.call(key) }
        attributes.merge!(source: "user_corrected", status: "corrected") if corrected
        attributes.merge!(reviewed_at: nil, high_impact_automation_approved_at: nil) if trust_changed
        memory_record.assign_attributes(attributes)
        next false if memory_record.invalid?

        MemoryRecord.transaction(requires_new: true) do
          memory_record.save!
          if body_corrected || correction_note.present?
            memory_record.memory_revisions.create!(user:, previous_body:, revised_body: memory_record.body, note: correction_note)
          end
        end
        true
      end
    end

    def self.normalize(key, value)
      case key
      when :title then value.to_s.squish
      when :body then value.to_s.strip
      else value.to_s
      end
    end
    private_class_method :normalize
  end
end
