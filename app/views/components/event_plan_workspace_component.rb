class EventPlanWorkspaceComponent < ApplicationViewComponent
  option :event_plan
  option :event_plans
  option :plan_task
  option :private_notes
  option :vault_items
  option :vault_unlocked, default: -> { false }
  option :next_reminder, default: -> { nil }
  option :backup_plan, default: -> { nil }
  option :personal_touch_checklist, default: -> { nil }
  option :vendors, default: -> { [] }

  style :primary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg bg-primary px-5 py-3
        text-sm font-semibold text-canvas transition hover:bg-primary-hover
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
  end

  style :secondary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg border border-private-line bg-canvas px-4 py-2
        text-sm font-semibold text-ink transition hover:bg-surface
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
  end

  style :kind_badge do
    base { %w[inline-flex rounded-full border px-2.5 py-1 text-xs font-semibold] }
    variants do
      origin do
        ai { %w[border-primary/30 bg-surface text-primary] }
        template { %w[border-private-line bg-surface text-quiet-note] }
        manual { %w[border-private-line bg-canvas text-quiet-note] }
      end
    end
    defaults { { origin: :manual } }
  end

  def progress = event_plan.progress

  def birthday_plan? = event_plan.occasion_type == "birthday"

  def anniversary_plan? = event_plan.occasion_type == "anniversary"

  def concierge_plan? = birthday_plan? || anniversary_plan?

  def concierge_key = birthday_plan? ? "birthday" : "anniversary"

  def next_action = @next_action ||= event_plan.next_action

  def birthday_timing
    return unless event_plan.starts_on

    owner_date = OwnerLocalCalendar.date_for(user: event_plan.user)
    days = (event_plan.starts_on - owner_date).to_i
    return t("event_plans.birthday.today") if days.zero?
    return t("event_plans.birthday.passed") if days.negative?

    t("event_plans.birthday.days_away", count: days)
  end

  def concierge_timing
    return birthday_timing if birthday_plan?
    return unless event_plan.starts_on

    owner_date = OwnerLocalCalendar.date_for(user: event_plan.user)
    days = (event_plan.starts_on - owner_date).to_i
    return t("event_plans.anniversary.today") if days.zero?
    return t("event_plans.anniversary.passed") if days.negative?

    t("event_plans.anniversary.days_away", count: days)
  end

  def next_action_path
    case next_action.kind
    when "gift_idea"
      relationship_profile_path(event_plan.relationship_profile, anchor: "gift-recommendations")
    when "message_draft"
      relationship_profile_path(event_plan.relationship_profile, anchor: "message-drafting")
    when "reminder"
      new_reminder_path(
        relationship_profile_id: event_plan.relationship_profile_id,
        event_plan_id: event_plan.id,
        plan_task_id: next_action.id
      )
    when "backup_step"
      event_plan_path(event_plan, anchor: "backup-options")
    else
      event_plan_path(event_plan, anchor: "plan-task-#{next_action.id}")
    end
  end

  def next_action_label
    t(
      "event_plans.#{concierge_key}.actions.#{next_action.kind}",
      default: t("event_plans.#{concierge_key}.actions.default")
    )
  end

  def planning_preference_label
    return t("event_plans.tones.#{event_plan.tone}") unless anniversary_plan?

    t(
      "event_plans.workspace.planning_preferences",
      tone: t("event_plans.tones.#{event_plan.tone}"),
      effort: t("event_plans.effort_levels.#{event_plan.effort_level}")
    )
  end

  def tasks_for(phase)
    event_plan.plan_tasks.select { |task| task.phase == phase && !task.superseded? }
  end

  def backup_plan_current?
    backup_plan&.generated? && backup_plan.event_plan_generation_version == event_plan.generation_version
  end

  def backup_plan_stale?
    backup_plan&.generated? && !backup_plan_current?
  end

  def backup_source_labels(option)
    option.source_context.filter_map { |source| source["label"] if source.is_a?(Hash) }.uniq
  end

  def backup_task_source_labels(blueprint)
    Array(blueprint["source_context"]).filter_map { |source| source["label"] if source.is_a?(Hash) }.uniq
  end

  def backup_task_due_on(blueprint)
    Date.iso8601(blueprint["due_on"].to_s) if blueprint["due_on"].present?
  end

  def replacement_tasks_for(option)
    tasks_by_id = event_plan.plan_tasks.index_by { |task| task.id.to_s }
    option.replacement_task_ids.filter_map { |task_id| tasks_by_id[task_id.to_s] }
  end

  def reviewed_reminders_for(option, task)
    option.reviewed_reminders.select { |reminder| reminder["plan_task_id"] == task.id }
  end

  def reviewed_reminder_delivery_at(reminder)
    value = reminder["snoozed_until"].presence || reminder.fetch("scheduled_at")
    Time.iso8601(value).in_time_zone(reminder.fetch("time_zone"))
  end

  def estimated_backup_cost(option)
    return t("event_plans.backup_plans.cost_levels.#{option.cost_level}") if option.estimated_cost_cents.nil?

    number_to_currency(option.estimated_cost_cents / 100.0)
  end

  def source_labels
    event_plan.source_context.filter_map { |source| source["label"] if source.is_a?(Hash) }.uniq
  end

  def task_source_labels(task)
    task.source_context.filter_map { |source| source["label"] if source.is_a?(Hash) }.uniq
  end

  def private_note_label(note)
    t(
      "event_plans.suggestions.private_note_label",
      date: l(note.created_at.to_date, format: :important_date),
      summary: note.body.to_plain_text.squish.truncate(80)
    )
  end

  def budget_value
    return if event_plan.budget_cents.nil?

    format("%.2f", event_plan.budget_cents / 100.0)
  end
end
