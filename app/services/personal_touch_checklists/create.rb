module PersonalTouchChecklists
  class Create
    MAX_PREFERENCE_SUGGESTIONS = 6

    GENERIC_PROMPTS = [
      [ "message", "handwritten_note" ],
      [ "preference", "meaningful_memory" ],
      [ "message", "private_message" ],
      [ "follow_up", "follow_up" ]
    ].freeze

    CATEGORY_MAP = {
      "allergies" => "dietary_need",
      "food" => "dietary_need",
      "gifts" => "gift",
      "communication" => "message",
      "boundaries" => "constraint",
      "cultural_constraints" => "constraint",
      "social_settings" => "preference",
      "general" => "preference"
    }.freeze

    def self.call(actor:, moment:, locale: I18n.locale)
      new(actor:, moment:, locale:).call
    end

    def initialize(actor:, moment:, locale: I18n.locale)
      @actor = actor
      @moment = moment
      @relationship_profile = moment.relationship_profile
      @locale = locale
    end

    def call
      raise ActiveRecord::RecordNotFound unless relationship_profile.user_id == actor.id

      PersonalTouchChecklist.transaction do
        actor.with_lock do
          relationship_profile.with_lock do
            moment.with_lock do
              validate_current_scope!
              checklist = find_or_initialize_checklist
              seed!(checklist) if checklist.new_record?
              checklist
            end
          end
        end
      end
    end

    private

    attr_reader :actor, :moment, :relationship_profile, :locale

    def validate_current_scope!
      relationship_profile.reload
      moment.reload
      raise ActiveRecord::RecordNotFound if relationship_profile.discarded?
      raise ActiveRecord::RecordNotFound unless moment.relationship_profile_id == relationship_profile.id
      raise ActiveRecord::RecordNotFound if moment.is_a?(EventPlan) && moment.archived?
    end

    def find_or_initialize_checklist
      attributes = moment.is_a?(EventPlan) ? { event_plan: moment } : { important_date: moment }
      relationship_profile.personal_touch_checklists.find_or_initialize_by(attributes)
    end

    def seed!(checklist)
      checklist.save!
      suggestions.each_with_index do |attributes, position|
        checklist.personal_touch_items.create!(attributes.merge(position:, origin: "suggested", status: "active"))
      end
      AuditEvent.record!(
        user: actor,
        actor:,
        action: "personal_touch_checklist.created",
        target: relationship_profile,
        metadata: { count: checklist.personal_touch_items.length }
      )
    end

    def suggestions
      generic_suggestions + preference_suggestions
    end

    def generic_suggestions
      GENERIC_PROMPTS.map do |category, key|
        {
          category:,
          title: translate("prompts.#{key}.title"),
          details: translate("prompts.#{key}.details"),
          source_context: []
        }
      end
    end

    def preference_suggestions
      relationship_profile.relationship_preferences
        .order(Arel.sql(<<~SQL.squish), :created_at, :id)
          CASE
            WHEN preference_type IN ('constraint', 'negative')
              OR category IN ('boundaries', 'allergies', 'cultural_constraints')
            THEN 0
            ELSE 1
          END
        SQL
        .limit(MAX_PREFERENCE_SUGGESTIONS)
        .map do |preference|
          {
            category: CATEGORY_MAP.fetch(preference.category, "preference"),
            title: bounded_preference_title(preference),
            details: nil,
            source_context: [
              {
                "source_type" => "RelationshipPreference",
                "source_id" => preference.id,
                "source_label" => bounded_source_label(preference),
                "certainty" => preference.confirmed? ? "confirmed" : "inferred"
              }
            ]
          }
        end
    end

    def bounded_preference_title(preference)
      translate("preference_prompt", key: preference.key, value: preference.value)
        .truncate(PersonalTouchItem::MAX_TITLE_LENGTH, omission: "…")
    end

    def bounded_source_label(preference)
      preference.key.truncate(PersonalTouchItem::MAX_SOURCE_LABEL_LENGTH, omission: "…")
    end

    def translate(key, **options)
      I18n.with_locale(locale) { I18n.t("personal_touch_checklists.suggestions.#{key}", **options) }
    end
  end
end
