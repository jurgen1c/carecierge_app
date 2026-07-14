class ReminderRowComponent < ApplicationViewComponent
  option :reminder
  option :compact, default: -> { false }

  style do
    base do
      %w[grid gap-3 border-b border-stone-200 py-4 last:border-b-0]
    end
    variants do
      urgency do
        overdue { %w[text-red-800] }
        due_today { %w[text-orange-800] }
        upcoming { %w[text-stone-700] }
      end
      compact do
        yes { %w[sm:grid-cols-[6rem_minmax(0,1fr)]] }
        no { %w[sm:grid-cols-[7rem_minmax(0,1fr)_auto]] }
      end
    end
    defaults { { urgency: :upcoming, compact: :no } }
  end

  style :dot do
    base { %w[absolute left-0 top-1.5 size-3 rounded-full border-2 border-white ring-2] }
    variants do
      urgency do
        overdue { %w[bg-red-700 ring-red-100] }
        due_today { %w[bg-orange-700 ring-orange-100] }
        upcoming { %w[bg-emerald-800 ring-emerald-100] }
      end
    end
    defaults { { urgency: :upcoming } }
  end

  def urgency
    return :overdue if reminder.overdue?
    return :due_today if reminder.due_today?

    :upcoming
  end

  def delivery_at
    reminder.effective_delivery_at
  end

  def relationship_name
    reminder.relationship_profile&.display_name
  end
end
