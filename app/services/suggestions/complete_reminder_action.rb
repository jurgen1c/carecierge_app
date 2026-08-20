module Suggestions
  class CompleteReminderAction
    def self.call(reminder:, suggestion:, user:)
      return reminder.save unless suggestion
      raise ActiveRecord::RecordNotFound unless reminder.relationship_profile_id == suggestion_profile_id(suggestion)

      Reminder.transaction do
        next false unless reminder.save

        feedback = user.suggestion_feedbacks.find_or_initialize_by(fingerprint: suggestion.fingerprint)
        feedback.relationship_profile = reminder.relationship_profile
        feedback.mark_acted!
        true
      end
    end

    def self.suggestion_profile_id(suggestion)
      source = suggestion.reasons.first.source
      source.is_a?(RelationshipProfile) ? source.id : source.relationship_profile_id
    end
    private_class_method :suggestion_profile_id
  end
end
