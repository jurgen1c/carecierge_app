class MessagingConnectionComponent < ApplicationViewComponent
  option :connection, optional: true
  option :contexts
  option :results, optional: true
  option :provider_available
  option :page, default: proc { 1 }
  option :more, default: proc { false }

  style :button do
    base { %w[inline-flex min-h-11 items-center justify-center rounded-lg border px-4 py-2 text-sm font-semibold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary] }
    variants do
      kind do
        primary { %w[border-primary bg-primary text-canvas hover:bg-primary-hover] }
        secondary { %w[border-private-line bg-canvas text-primary hover:bg-surface] }
        danger { %w[border-danger-border bg-canvas text-danger-ink hover:bg-danger-surface] }
      end
    end
    defaults { { kind: :secondary } }
  end
  style :input do
    base { %w[min-h-11 w-full rounded-lg border border-private-line bg-canvas px-3 py-2 text-sm text-ink focus-visible:outline focus-visible:outline-2 focus-visible:outline-primary] }
  end

  def ready? = connection&.status == "connected"
end
