module Concierge
  module Operations
    class Ideas < Base
      SCOPE = { relationship_profile_id: :uuid, variation: Suggestion::GESTURE_VARIATIONS }.freeze
      IDENTITY = SCOPE.merge(fingerprint: :string).freeze

      def self.namespace = "ideas"

      def self.definitions
        [ define("search", description: "Find current source-backed relationship suggestions. These are ideas, not facts. Hidden suggestions are excluded. Variations are low, medium or high effort.", fields: SCOPE, read_only: true),
          define("read", description: "Read a current suggestion by the exact returned fingerprint and variation.", fields: IDENTITY, required: %w[fingerprint], read_only: true),
          define("alternative", description: "Offer the next available gesture variation, skipping dismissed or completed alternatives.", fields: IDENTITY, required: %w[fingerprint], read_only: true),
          define("feedback", description: "Record helpful or not-for-me feedback on this exact suggestion.", fields: IDENTITY.merge(feedback: SuggestionFeedback::FEEDBACK_VALUES), required: %w[fingerprint feedback]),
          define("remind", description: "Create an internal reminder for this exact suggestion at a specified ISO time. Marks it acted only after the reminder is saved. Clarify missing time.", fields: IDENTITY.merge(scheduled_at: :datetime), required: %w[fingerprint scheduled_at], capability: "send_reminders") ] +
          %w[save complete dismiss].map do |action|
            define(action, description: "#{action.capitalize} this exact suggestion. Saving and completing apply to gestures; completion records what the user reports doing.", fields: IDENTITY, required: %w[fingerprint])
          end
      end

      def target
        idea.reasons.first.source if arguments["fingerprint"]
      end

      def idea
        @idea ||= candidates.find { |candidate| candidate.fingerprint == arguments["fingerprint"] } || raise(ActiveRecord::RecordNotFound)
      end

      def precondition
        reference(idea).slice("record_type", "id", "version")
      end

      def preview
        [ idea.title, idea.detail, arguments["scheduled_at"] ].compact.join(" · ")
      end

      def search
        authorize!(profile, :show)
        feedbacks = user.suggestion_feedbacks.where(fingerprint: candidates.map(&:fingerprint)).index_by(&:fingerprint)
        { "records" => candidates.reject { |candidate| feedbacks[candidate.fingerprint]&.hidden? }.map { |candidate| reference(candidate) } }
      end

      def read
        authorize!(profile, :show)
        { "record" => reference(idea) }
      end

      def alternative
        authorize!(profile, :show)
        variation = ::Suggestions::NextGestureVariation.call(user:, relationship_profile: profile, suggestion: idea)
        alternative = SuggestionSources.for_profile(profile:, turn:, variation:).find(&:gesture?) if variation
        { "record" => alternative && reference(alternative), "alternatives_exhausted" => alternative.nil? }.compact
      end

      def feedback
        change_feedback(:feedback) { |record| record.record_feedback!(arguments.fetch("feedback")) }
      end

      def dismiss
        change_feedback(:dismiss, &:dismiss!)
      end

      def save
        raise InvalidArguments unless idea.gesture?
        change_feedback(:save, &:save_for_later!)
      end

      def complete
        raise InvalidArguments unless idea.gesture?
        change_feedback(:complete, &:mark_acted!)
      end

      def remind
        raise PermissionDenied unless idea.high_impact_evidence_eligible?
        reminder = user.reminders.new(**idea.reminder_attributes, relationship_profile: profile,
          scheduled_at: arguments.fetch("scheduled_at"), time_zone: OwnerLocalCalendar.time_zone_for(user:).name)
        authorize!(reminder, :create)
        source = idea.reasons.first.source
        reminder.commitment = source if source.is_a?(Commitment)
        reminder.important_date = source if source.is_a?(ImportantDate)
        ProfessionalScope.create_and_select!(handler: self, collection: "reminders") do
          AuditEvents::Track.call(user:, actor: user, action: "reminder.created", target: reminder) do
            raise ActiveRecord::RecordInvalid, reminder unless ::Suggestions::CompleteReminderAction.call(reminder:, suggestion: idea, user:)
          end
          reminder
        end
        { "record" => receipt(reminder, title: reminder.title, body: reminder.notes,
            scheduled_at: reminder.local_scheduled_at.iso8601, time_zone: reminder.time_zone, state: reminder.status),
          "records" => [ reference(idea) ] }
      end

      private

      def candidates
        @candidates ||= SuggestionSources.for_profile(profile:, turn:, variation: arguments["variation"])
      end

      def reference(value)
        SuggestionSources.reference(value, profile:, turn:)
      end

      def change_feedback(action)
        record = user.suggestion_feedbacks.find_or_initialize_by(fingerprint: idea.fingerprint)
        record.relationship_profile = profile
        authorize!(record, action)
        yield record
        { "record" => reference(idea) }
      end
    end
  end
end
