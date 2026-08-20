require "digest"

module Suggestions
  class ForProfile
    TYPE_ORDER = Suggestion::TYPES.each_with_index.to_h.freeze
    PROFESSIONAL_TYPES = %w[
      RelationshipProfiles::Boss RelationshipProfiles::Manager RelationshipProfiles::DirectReport
      RelationshipProfiles::Coworker RelationshipProfiles::Colleague RelationshipProfiles::BusinessPartner
      RelationshipProfiles::Client RelationshipProfiles::Customer RelationshipProfiles::Vendor
    ].freeze
    REPAIR_CATEGORIES = %w[stressed distant sad overwhelmed].freeze

    def self.call(relationship_profile:, as_of: Time.current, mood_notes: nil, important_dates: nil, interactions: nil,
      social_context_notes: nil, gesture_variation: nil, include_profile_gesture_fallback: true,
      use_preloaded_persona_sources: false)
      new(
        relationship_profile:,
        as_of:,
        mood_notes:,
        important_dates:,
        interactions:,
        social_context_notes:,
        gesture_variation:,
        include_profile_gesture_fallback:,
        use_preloaded_persona_sources:
      ).call
    end

    def initialize(relationship_profile:, as_of:, mood_notes:, important_dates:, interactions:, social_context_notes:,
      gesture_variation:, include_profile_gesture_fallback:, use_preloaded_persona_sources:)
      @relationship_profile = relationship_profile
      @as_of = as_of
      @mood_notes = mood_notes
      @important_dates = important_dates
      @interactions = interactions
      @provided_social_context_notes = social_context_notes
      @gesture_variation = gesture_variation.to_s.in?(Suggestion::GESTURE_VARIATIONS) ? gesture_variation.to_s : "low"
      @include_profile_gesture_fallback = include_profile_gesture_fallback
      @use_preloaded_persona_sources = use_preloaded_persona_sources
    end

    def call
      return [] if relationship_profile.archived?

      [
        gift_suggestion,
        message_suggestion,
        social_context_suggestion("conversation_topic", reminder_type: "custom"),
        plan_suggestion,
        check_in_suggestion,
        social_context_suggestion("reminder", suggestion_type: "social_reminder", reminder_type: "check_in"),
        event_suggestion,
        spontaneous_suggestion,
        repair_suggestion,
        professional_follow_up_suggestion
      ].compact.sort_by { |suggestion| TYPE_ORDER.fetch(suggestion.suggestion_type) }
    end

    private

    attr_reader :relationship_profile, :as_of, :mood_notes, :important_dates, :interactions, :provided_social_context_notes,
      :gesture_variation, :use_preloaded_persona_sources

    def gift_suggestion
      desire = active_desires.find { |item| item.suggestion_contexts.include?("gift") }
      return build("gift", desire, evidence: desire.title, reminder_type: "gift_planning") if desire

      social_context_suggestion("gift", reminder_type: "gift_planning")
    end

    def message_suggestion
      input = RelationshipPersona.new(
        relationship_profile:,
        use_preloaded_associations: use_preloaded_persona_sources
      ).suggestion_inputs.first
      return social_context_suggestion("message", reminder_type: "check_in") unless input

      source = persona_source(input)
      return social_context_suggestion("message", reminder_type: "check_in") unless source

      build(
        "message",
        source,
        evidence: input.fetch(:evidence),
        certainty: input.fetch(:certainty),
        reminder_type: "check_in"
      )
    end

    def social_context_suggestion(use, suggestion_type: use, reminder_type:)
      note = social_context_notes.find { |item| item.approved_suggested_uses.include?(use) }
      return unless note

      build(
        suggestion_type,
        note,
        evidence: note.suggestion_evidence,
        certainty: note.suggestion_certainty,
        reminder_type:
      )
    end

    def plan_suggestion
      desire = active_desires.find { |item| (item.suggestion_contexts & %w[date plan]).any? }
      build("plan", desire, evidence: desire&.title, reminder_type: "relationship_goal")
    end

    def check_in_suggestion
      cadence = relationship_profile.contact_cadence
      return unless cadence&.overdue?(as_of:)

      build(
        "check_in",
        cadence,
        evidence: I18n.l(cadence.next_check_in_at.to_date, format: :long),
        reminder_type: "check_in"
      )
    end

    def event_suggestion
      important_date = (important_dates || relationship_profile.important_dates.reload)
        .select { |item| item.planning_opportunity?(as_of: as_of.to_date) }
        .min_by { |item| [ item.next_occurrence_on(as_of: as_of.to_date), item.title.to_s, item.id ] }
      build("event", important_date, evidence: important_date&.display_title, reminder_type: "event_preparation", priority: "high")
    end

    def spontaneous_suggestion
      source = gesture_source
      build(
        "spontaneous",
        source,
        evidence: gesture_evidence(source),
        certainty: gesture_certainty(source),
        reminder_type: "check_in",
        effort: gesture_variation,
        variation: gesture_variation
      )
    end

    def gesture_source
      case gesture_variation
      when "low"
        recent_interaction || relationship_profile.contact_cadence || profile_gesture_fallback
      when "medium"
        safe_gesture_preference || upcoming_important_date || profile_gesture_fallback
      when "high"
        active_desires.find { |item| item.suggestion_contexts.include?("gesture") } ||
          upcoming_important_date || profile_gesture_fallback
      end
    end

    def profile_gesture_fallback
      relationship_profile if @include_profile_gesture_fallback
    end

    def recent_interaction
      collection = if interactions
        interactions
      elsif use_preloaded_persona_sources
        association = relationship_profile.association(:interactions)
        association.loaded? ? association.target : []
      else
        relationship_profile.interactions.ordered.limit(10).to_a
      end

      collection.select { |item| item.occurred_at.between?(as_of - 30.days, as_of) }
        .max_by { |item| [ item.occurred_at, item.id ] }
    end

    def safe_gesture_preference
      preferences = if use_preloaded_persona_sources
        relationship_profile.relationship_preferences
      else
        relationship_profile.relationship_preferences.reload
      end

      preferences
        .select { |item| item.preference_type.in?(%w[positive neutral]) }
        .reject { |item| item.category.in?(%w[boundaries allergies cultural_constraints]) }
        .min_by { |item| [ item.confidence == "confirmed" ? 0 : 1, item.key.downcase, item.id ] }
    end

    def upcoming_important_date
      (important_dates || relationship_profile.important_dates.reload)
        .select { |item| item.planning_opportunity?(as_of: as_of.to_date) }
        .min_by { |item| [ item.next_occurrence_on(as_of: as_of.to_date), item.title.to_s, item.id ] }
    end

    def gesture_evidence(source)
      case source
      when Interaction
        I18n.t(
          "suggestions.evidence.recent_interaction",
          type: I18n.t("relationship_searches.interaction_types.#{source.interaction_type}"),
          date: I18n.l(source.occurred_at.to_date, format: :long)
        )
      when ContactCadence
        I18n.t("suggestions.evidence.contact_cadence", days: source.interval_days)
      when RelationshipPreference then source.value
      when ImportantDate then source.display_title
      when Desire then source.title
      when RelationshipProfile then source.relationship_type_label
      end
    end

    def gesture_certainty(source)
      return "inferred" if source.is_a?(RelationshipPreference) && source.confidence != "confirmed"

      "confirmed"
    end

    def repair_suggestion
      mood_note = (mood_notes || relationship_profile.mood_notes)
        .select { |item| item.category.in?(REPAIR_CATEGORIES) && item.observed_at >= as_of - 30.days }
        .max_by { |item| [ item.observed_at, item.id ] }
      build("repair_focused", mood_note, evidence: mood_note&.observation, reminder_type: "check_in", priority: "high")
    end

    def professional_follow_up_suggestion
      return unless relationship_profile.type.in?(PROFESSIONAL_TYPES)

      commitment = relationship_profile.commitments
        .select { |item| item.overdue?(as_of.to_date) }
        .min_by { |item| [ item.due_on, item.title, item.id ] }
      build("professional_follow_up", commitment, evidence: commitment&.title, reminder_type: "promise_follow_up", priority: "high")
    end

    def active_desires
      @active_desires ||= relationship_profile.desires
        .select { |desire| desire.status.in?(Desire::EDITABLE_STATUSES) }
        .sort_by { |desire| [ desire.status == "active" ? 0 : 1, desire.title.downcase, desire.id ] }
    end

    def social_context_notes
      return @social_context_notes if defined?(@social_context_notes)

      @social_context_notes = if provided_social_context_notes
        SocialContextNote.select_downstream_sources(provided_social_context_notes)
      else
        relationship_profile.social_context_notes
          .downstream_sources
          .to_a
      end
    end

    def persona_source(input)
      source_class = input.fetch(:source_type).safe_constantize
      return unless source_class&.reflect_on_association(:relationship_profile)

      loaded_source = loaded_persona_source(source_class, input.fetch(:source_id)) if use_preloaded_persona_sources
      return loaded_source if loaded_source

      source_class.find_by(id: input.fetch(:source_id), relationship_profile_id: relationship_profile.id)
    end

    def loaded_persona_source(source_class, source_id)
      association_name = {
        "MemoryRecord" => :memory_records,
        "RelationshipPreference" => :relationship_preferences
      }[source_class.base_class.name]
      return unless association_name

      association = relationship_profile.association(association_name)
      return unless association.loaded?

      association.target.find { |record| record.id == source_id }
    end

    def build(type, source, evidence:, certainty: "confirmed", reminder_type:, priority: "normal", effort: nil, variation: nil)
      return if source.blank? || evidence.blank?

      reason = Suggestion::Reason.new(
        label_key: "suggestions.reasons.#{type}",
        label_params: { name: relationship_profile.display_name },
        evidence: evidence.to_s,
        certainty:,
        source:
      )
      fingerprint = Suggestion.fingerprint_for(
        relationship_profile_id: relationship_profile.id,
        suggestion_type: type,
        source_type: source.class.base_class.name,
        source_id: source.id,
        variant: variation
      )

      copy_key = variation ? "#{type}.#{variation}" : type

      Suggestion.new(
        fingerprint:,
        suggestion_type: type,
        title_key: "suggestions.types.#{copy_key}.title",
        title_params: { name: relationship_profile.display_name },
        detail_key: "suggestions.types.#{copy_key}.detail",
        detail_params: { name: relationship_profile.display_name },
        reasons: [ reason ],
        action_kind: "create_reminder",
        action_attributes: { reminder_type:, priority: },
        effort:,
        variation:
      )
    end
  end
end
