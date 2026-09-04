class BookingListComponent < ApplicationViewComponent
  option :event_plan
  option :bookings
  option :editable, default: -> { false }
  option :compact, default: -> { false }
  option :show_header, default: -> { true }
  option :dom_id, default: -> { "bookings" }

  style :status_badge do
    base { %w[inline-flex rounded-full border px-2.5 py-1 text-xs font-semibold] }
    variants do
      status do
        planned { %w[border-private-line bg-canvas text-quiet-note] }
        requested { %w[border-private-line bg-surface text-ink] }
        confirmed { %w[border-primary/30 bg-surface text-primary] }
        completed { %w[border-primary/30 bg-surface text-primary] }
        cancelled { %w[border-private-line bg-surface text-quiet-note] }
      end
    end
    defaults { { status: :planned } }
  end

  style :primary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg bg-primary px-5 py-3
        text-sm font-semibold text-canvas hover:bg-primary-hover
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
  end

  style :secondary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg border border-private-line bg-canvas px-4 py-2
        text-sm font-semibold text-ink hover:bg-surface
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary
      ]
    end
  end

  style :danger_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg border border-danger-border bg-canvas px-4 py-2
        text-sm font-semibold text-danger-ink hover:bg-danger-surface
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-danger-ink
      ]
    end
  end

  def visible_bookings = compact ? bookings.first(3) : bookings

  def booking_time(booking)
    l(booking.local_starts_at, format: :long)
  end

  def reminder_count(booking)
    reminders = booking.reminders
    reminders.loaded? ? reminders.count(&:active?) : reminders.active.count
  end

  def available_reminder_milestones(booking)
    Reminder::BOOKING_MILESTONES - booking.obsolete_reminder_milestones
  end

  def reminder_path(booking, milestone)
    new_reminder_path(
      event_plan_id: event_plan.id,
      booking_id: booking.id,
      booking_milestone: milestone
    )
  end
end
