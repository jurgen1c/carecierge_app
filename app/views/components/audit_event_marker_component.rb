class AuditEventMarkerComponent < ApplicationViewComponent
  option :tone, default: -> { :standard }

  style do
    base { %w[mt-1.5 block size-3 shrink-0 rounded-full border-2 border-white ring-1] }
    variants do
      tone do
        standard { %w[bg-emerald-700 ring-emerald-700] }
        security { %w[bg-amber-600 ring-amber-600] }
        deletion { %w[bg-red-700 ring-red-700] }
      end
    end
    defaults { { tone: :standard } }
  end
end
