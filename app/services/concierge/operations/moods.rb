module Concierge
  module Operations
    class Moods < ProfileRecords
      CLEARABLE_FIELDS = %w[follow_up_at supportive_action].freeze
      NAMESPACE = "moods"
      ASSOCIATION = :mood_notes
      FIELDS = { category: MoodNote::CATEGORIES, observation: :string, observed_at: :datetime,
        supportive_action: :string, follow_up_at: :datetime, timeline_visible: :boolean }.freeze
      REQUIRED = %w[category observation].freeze
      SEARCH = :observation_or_supportive_action_cont
      TITLE = :display_title
      BODY = :observation

      private

      def persist!(record)
        record.assign_attributes(attributes)
        raise ActiveRecord::RecordInvalid, record unless MoodNotes::Save.call(record)
      end
    end
  end
end
