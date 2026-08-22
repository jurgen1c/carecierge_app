class EventPlanWorkspaceComponent < ApplicationViewComponent
  option :event_plan
  option :event_plans
  option :plan_task
  option :private_notes
  option :vault_items
  option :vault_unlocked, default: -> { false }
  option :next_reminder, default: -> { nil }

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

  def tasks_for(phase)
    event_plan.plan_tasks.select { |task| task.phase == phase }
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
