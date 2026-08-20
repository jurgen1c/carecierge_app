module Suggestions
  class NextGestureVariation
    def self.call(user:, relationship_profile:, suggestion:, as_of: Time.current, mood_notes: nil,
      important_dates: nil, interactions: nil, social_context_notes: nil, use_preloaded_persona_sources: false)
      return unless suggestion&.gesture?
      return unless relationship_profile.user_id == user.id

      alternatives = Suggestion::GESTURE_VARIATIONS - [ suggestion.variation ]
      gestures_by_variation = alternatives.index_with do |variation|
        Suggestions::ForProfile.call(
          relationship_profile:,
          as_of:,
          mood_notes:,
          important_dates:,
          interactions:,
          social_context_notes:,
          gesture_variation: variation,
          use_preloaded_persona_sources:
        ).find(&:gesture?)
      end
      unavailable_variations = gestures_by_variation.filter_map { |variation, gesture| variation unless gesture }
      hidden_fingerprints = user.suggestion_feedbacks
        .where(fingerprint: gestures_by_variation.values.compact.map(&:fingerprint))
        .select(&:hidden?)
        .map(&:fingerprint)
        .to_set
      hidden_variations = gestures_by_variation.filter_map do |variation, gesture|
        variation if gesture && gesture.fingerprint.in?(hidden_fingerprints)
      end

      suggestion.alternative_variation(excluding: unavailable_variations + hidden_variations)
    end
  end
end
