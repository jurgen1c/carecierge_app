class VendorShortlistComparisonComponent < ApplicationViewComponent
  option :shortlist
  option :options
  option :editable, default: -> { false }
  option :removable, default: -> { false }

  style :status_badge do
    base { %w[inline-flex rounded-full border px-2.5 py-1 text-xs font-semibold] }
    variants do
      decision do
        considering { %w[border-private-line bg-canvas text-quiet-note] }
        rejected { %w[border-danger-border bg-danger-surface text-danger-ink] }
        selected { %w[border-primary/30 bg-surface text-primary] }
      end
    end
    defaults { { decision: :considering } }
  end

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

  style :danger_button do
    base do
      %w[
        inline-flex min-h-11 items-center justify-center rounded-lg border border-danger-border bg-canvas px-4 py-2
        text-sm font-semibold text-danger-ink transition hover:bg-danger-surface
        focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-danger-ink
      ]
    end
  end

  def comparison_rows
    %i[price availability location fit notes constraints next_action]
  end

  def comparison_value(option, row)
    value = case row
    when :price then option.vendor.price_range
    when :availability then option.vendor.availability
    when :location then option.vendor.location
    when :fit then option.vendor.fit_notes
    when :notes then option.notes
    when :constraints then option.constraints
    when :next_action then option.next_action
    end

    value.presence || t("vendor_shortlists.comparison.not_provided")
  end

  def favorite_label(option)
    key = option.favorite? ? "remove_favorite" : "favorite"
    t("vendor_shortlists.options.actions.#{key}")
  end
end
