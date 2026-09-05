class ExternalProviderActionComponent < ApplicationViewComponent
  option :record
  option :time_zone, default: -> { "UTC" }

  style :status_label do
    base { %w[inline-flex rounded-lg border px-3 py-1 text-sm font-semibold] }
    variants do
      failed do
        yes { %w[border-danger-border text-danger-ink bg-danger-surface] }
        no { %w[border-private-line text-ink bg-surface] }
      end
    end
    defaults { { failed: :no } }
  end
end
