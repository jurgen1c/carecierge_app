module EventPlans
  class Template
    Seed = Data.define(:phase, :kind, :title_key, :details_key, :days_before)

    GENERIC_SEEDS = [
      Seed.new("decide", "milestone", "define_moment", "define_moment", 42),
      Seed.new("decide", "decision", "confirm_format", "confirm_format", 35),
      Seed.new("decide", "task", "confirm_guests", "confirm_guests", 28),
      Seed.new("arrange", "vendor_need", "identify_vendors", "identify_vendors", 21),
      Seed.new("arrange", "gift_idea", "choose_gift", "choose_gift", 18),
      Seed.new("arrange", "message_draft", "draft_message", "draft_message", 14),
      Seed.new("arrange", "reminder", "set_reminder", "set_reminder", 10),
      Seed.new("follow_through", "backup_step", "prepare_backup", "prepare_backup", 3),
      Seed.new("follow_through", "milestone", "event_day", "event_day", 0)
    ].freeze

    def self.for(occasion_type:, starts_on:, locale: I18n.locale)
      GENERIC_SEEDS.each_with_index.map do |seed, position|
        {
          phase: seed.phase,
          kind: seed.kind,
          title: translate(seed.title_key, occasion_type:, locale:),
          details: translate(seed.details_key, occasion_type:, locale:, scope: :details),
          due_on: deadline_for(position:, starts_on:),
          position:,
          origin: "template",
          source_context: []
        }
      end
    end

    def self.deadline_for(position:, starts_on:)
      return unless starts_on

      starts_on - GENERIC_SEEDS.fetch(position).days_before.days
    end

    def self.translate(key, occasion_type:, locale:, scope: :titles)
      I18n.with_locale(locale) do
        I18n.t("event_plans.templates.#{occasion_type}.#{scope}.#{key}",
          default: I18n.t("event_plans.templates.default.#{scope}.#{key}"))
      end
    end

    private_class_method :translate
  end
end
