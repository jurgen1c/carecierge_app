class NotificationSwitchRowComponent < ApplicationViewComponent
  option :form
  option :field
  option :title
  option :description
  option :availability, optional: true
  option :attention, default: -> { false }

  style do
    base { %w[flex min-h-16 cursor-pointer items-center justify-between gap-4 px-4 py-3 sm:px-5] }
  end

  style :attention do
    base { %w[items-center gap-1.5 text-xs font-medium text-orange-800] }
    variants do
      attention do
        yes { %w[inline-flex] }
        no { %w[hidden] }
      end
    end
    defaults { { attention: :no } }
  end

  style :track do
    base { %w[h-7 w-12 rounded-full bg-stone-300 transition peer-checked:bg-emerald-800 peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-emerald-700] }
  end

  style :thumb do
    base { %w[pointer-events-none absolute left-1 size-5 rounded-full bg-white transition peer-checked:translate-x-5] }
  end
end
