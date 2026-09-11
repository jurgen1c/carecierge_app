module Concierge
  class SuggestionSources
    def self.for_profile(profile:, turn:, variation: nil)
      Time.use_zone(OwnerLocalCalendar.time_zone_for(user: profile.user)) do
        ::Suggestions::ForProfile.call(relationship_profile: profile, gesture_variation: variation).select do |idea|
          sources(idea, turn:).all? { |source| History.source_current?(source, user: profile.user, turn:) }
        end
      end
    end

    def self.reference(idea, profile:, turn:)
      feedback = profile.user.suggestion_feedbacks.find_by(fingerprint: idea.fingerprint)
      references = sources(idea, turn:)
      state = feedback&.attributes&.slice("feedback", "saved_at", "acted_at", "dismissed_at") || {}
      { "record_type" => "Suggestion", "id" => idea.fingerprint, "relationship_profile_id" => profile.id,
        "title" => idea.title, "body" => idea.detail, "variation" => idea.variation,
        "suggestion_type" => idea.suggestion_type, "certainty" => "inferred", "source_certainty" => idea.certainty,
        "sources" => references, "feedback" => state,
        "version" => RecordVersion.digest([ idea.fingerprint, idea.title, idea.detail, references, state ]) }.compact
    end

    def self.current?(reference, user:, turn:)
      profile = user.relationship_profiles.active.find_by(id: reference["relationship_profile_id"])
      return false unless profile && turn

      I18n.with_locale(turn.locale) do
        idea = for_profile(profile:, turn:, variation: reference["variation"]).find { |item| item.fingerprint == reference["id"] }
        idea.present? && self.reference(idea, profile:, turn:)["version"] == reference["version"]
      end
    end

    def self.sources(idea, turn:)
      builder = Operations::Base.new(turn:, arguments: {})
      idea.reasons.map { |reason| builder.receipt(reason.source, title: reason.label, body: reason.evidence, certainty: reason.certainty) }
    end
    private_class_method :sources
  end
end
