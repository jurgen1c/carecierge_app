module EventPlans
  class Template
    Seed = Data.define(:phase, :kind, :title_key, :details_key, :days_before, :minimum_effort)

    GENERIC_SEEDS = [
      Seed.new("decide", "milestone", "define_moment", "define_moment", 42, "low"),
      Seed.new("decide", "decision", "confirm_format", "confirm_format", 35, "low"),
      Seed.new("decide", "task", "confirm_guests", "confirm_guests", 28, "low"),
      Seed.new("arrange", "vendor_need", "identify_vendors", "identify_vendors", 21, "low"),
      Seed.new("arrange", "gift_idea", "choose_gift", "choose_gift", 18, "low"),
      Seed.new("arrange", "message_draft", "draft_message", "draft_message", 14, "low"),
      Seed.new("arrange", "reminder", "set_reminder", "set_reminder", 10, "low"),
      Seed.new("follow_through", "backup_step", "prepare_backup", "prepare_backup", 3, "low"),
      Seed.new("follow_through", "milestone", "event_day", "event_day", 0, "low")
    ].freeze

    ANNIVERSARY_SEEDS = [
      Seed.new("decide", "milestone", "define_anniversary", "define_anniversary", 42, "low"),
      Seed.new("decide", "task", "choose_activity", "choose_activity", 35, "medium"),
      Seed.new("arrange", "vendor_need", "review_reservation", "review_reservation", 28, "medium"),
      Seed.new("arrange", "gift_idea", "choose_anniversary_gift", "choose_anniversary_gift", 21, "medium"),
      Seed.new("arrange", "task", "consider_flowers", "consider_flowers", 18, "medium"),
      Seed.new("arrange", "message_draft", "draft_anniversary_message", "draft_anniversary_message", 14, "low"),
      Seed.new("arrange", "reminder", "set_anniversary_reminder", "set_anniversary_reminder", 10, "low"),
      Seed.new("follow_through", "task", "add_personal_touch", "add_personal_touch", 7, "low"),
      Seed.new("follow_through", "backup_step", "prepare_anniversary_backup", "prepare_anniversary_backup", 3, "high"),
      Seed.new("follow_through", "task", "confirm_childcare", "confirm_childcare", 2, "high"),
      Seed.new("follow_through", "milestone", "anniversary_day", "anniversary_day", 0, "low")
    ].freeze
    EFFORT_RANK = { "low" => 0, "medium" => 1, "high" => 2 }.freeze

    def self.for(occasion_type:, starts_on:, tone: "warm", effort_level: "medium", locale: I18n.locale)
      build(
        indexed_seeds(occasion_type:, effort_level:),
        occasion_type:,
        starts_on:,
        tone:,
        locale:
      )
    end

    def self.legacy_anniversary_for(starts_on:, locale: I18n.locale)
      build(
        GENERIC_SEEDS.each_with_index.map { |seed, position| [ position, seed ] },
        occasion_type: "anniversary",
        starts_on:,
        tone: "warm",
        locale:
      )
    end

    def self.build(indexed_seeds, occasion_type:, starts_on:, tone:, locale:)
      indexed_seeds.map do |position, seed|
        {
          phase: seed.phase,
          kind: seed.kind,
          title: translate(seed.title_key, occasion_type:, locale:),
          details: translate(seed.details_key, occasion_type:, locale:, scope: :details, tone:),
          due_on: starts_on && starts_on - seed.days_before.days,
          position:,
          origin: "template",
          source_context: []
        }
      end
    end

    def self.deadline_for(position:, starts_on:, occasion_type: "custom")
      return unless starts_on

      seeds = occasion_type.to_s == "anniversary" ? ANNIVERSARY_SEEDS : GENERIC_SEEDS
      seed = seeds[position]
      return unless seed

      starts_on - seed.days_before.days
    end

    def self.indexed_seeds(occasion_type:, effort_level:)
      seeds = occasion_type.to_s == "anniversary" ? ANNIVERSARY_SEEDS : GENERIC_SEEDS
      maximum_rank = EFFORT_RANK.fetch(effort_level.to_s, EFFORT_RANK.fetch("medium"))

      seeds.each_with_index.filter_map do |seed, position|
        [ position, seed ] if EFFORT_RANK.fetch(seed.minimum_effort) <= maximum_rank
      end
    end

    def self.translate(key, occasion_type:, locale:, scope: :titles, tone: "warm")
      I18n.with_locale(locale) do
        I18n.t("event_plans.templates.#{occasion_type}.#{scope}.#{key}",
          tone: I18n.t("event_plans.tones.#{tone}"),
          default: I18n.t("event_plans.templates.default.#{scope}.#{key}"))
      end
    end

    private_class_method :build, :indexed_seeds, :translate
  end
end
