class VendorResultComponent < ApplicationViewComponent
  option :vendor
  option :event_plan, default: -> { nil }
  option :search, default: -> { nil }

  style :primary_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg bg-primary px-4 py-2
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

  def fit_explanation
    search ? search.explanation_for(vendor) : vendor.fit_notes.presence || t("vendors.matches.default")
  end

  def assignment
    @assignment ||= vendor.event_plan_vendors.find { |item| item.event_plan_id == event_plan&.id }
  end
end
