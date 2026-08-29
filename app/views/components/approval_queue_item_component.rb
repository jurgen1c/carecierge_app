class ApprovalQueueItemComponent < ApplicationViewComponent
  option :item
  option :mode, default: -> { nil }
  option :status, default: -> { "pending" }
  option :page, default: -> { nil }

  style :risk do
    base { %w[inline-flex rounded-full border px-2 py-1 text-xs font-semibold] }
    variants do
      level do
        low { %w[border-private-line bg-surface text-quiet-note] }
        medium { %w[border-private-line bg-surface text-ink] }
        high { %w[border-danger-border bg-danger-surface text-danger-ink] }
        sensitive { %w[border-danger-border bg-danger-surface text-danger-ink] }
      end
    end
  end

  style :button do
    base do
      %w[inline-flex min-h-11 items-center justify-center rounded-lg border px-4 py-2 text-sm font-semibold transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary]
    end
    variants do
      tone do
        primary { %w[border-primary bg-primary text-canvas hover:bg-primary-hover] }
        secondary { %w[border-private-line bg-canvas text-ink hover:bg-surface] }
        quiet { %w[border-transparent bg-canvas text-quiet-note hover:bg-surface hover:text-ink] }
        danger { %w[border-danger-border bg-canvas text-danger-ink hover:bg-danger-surface] }
      end
    end
  end

  def approval_request
    item.approval_request
  end

  def decision_params(decision)
    { approval_request: { decision:, lock_version: item.lock_version } }
  end

  def queue_path(mode: nil)
    approvals_path(status:, page:, id: item.id, mode:)
  end

  def decision_path(mode: nil)
    approval_path(approval_request, page:, mode:)
  end

  def deferral_min
    minimum = 1.minute.from_now.in_time_zone(owner_time_zone)
    minimum = minimum.beginning_of_minute + 1.minute unless minimum.sec.zero?
    minimum.strftime("%Y-%m-%dT%H:%M")
  end

  private

  def owner_time_zone
    OwnerLocalCalendar.time_zone_for(user: approval_request.user)
  end
end
