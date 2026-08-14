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

    def self.call(relationship_profile:, as_of: Time.current, mood_notes: nil, important_dates: nil, social_context_notes: nil)
      new(relationship_profile:, as_of:, mood_notes:, important_dates:, social_context_notes:).call
    end

    def initialize(relationship_profile:, as_of:, mood_notes:, important_dates:, social_context_notes:)
      @relationship_profile = relationship_profile
      @as_of = as_of
      @mood_notes = mood_notes
      @important_dates = important_dates
      @provided_social_context_notes = social_context_notes
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

    attr_reader :relationship_profile, :as_of, :mood_notes, :important_dates, :provided_social_context_notes

    def gift_suggestion
      desire = active_desires.find { |item| item.suggestion_contexts.include?("gift") }
      return build("gift", desire, evidence: desire.title, reminder_type: "gift_planning") if desire

      social_context_suggestion("gift", reminder_type: "gift_planning")
    end

    def message_suggestion
      input = RelationshipPersona.new(relationship_profile:).suggestion_inputs.first
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
      desire = active_desires.find { |item| item.suggestion_contexts.include?("gesture") }
      build("spontaneous", desire, evidence: desire&.title, reminder_type: "check_in")
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

      source_class.find_by(id: input.fetch(:source_id), relationship_profile_id: relationship_profile.id)
    end

    def build(type, source, evidence:, certainty: "confirmed", reminder_type:, priority: "normal")
      return if source.blank? || evidence.blank?

      reason = Suggestion::Reason.new(
        label_key: "suggestions.reasons.#{type}",
        label_params: { name: relationship_profile.display_name },
        evidence: evidence.to_s,
        certainty:,
        source:
      )
      fingerprint = Digest::SHA256.hexdigest(
        [ "v1", relationship_profile.id, type, source.class.base_class.name, source.id ].join(":"),
      )

      Suggestion.new(
        fingerprint:,
        suggestion_type: type,
        title_key: "suggestions.types.#{type}.title",
        title_params: { name: relationship_profile.display_name },
        detail_key: "suggestions.types.#{type}.detail",
        detail_params: { name: relationship_profile.display_name },
        reasons: [ reason ],
        action_kind: "create_reminder",
        action_attributes: { reminder_type:, priority: }
      )
    end
  end
end
