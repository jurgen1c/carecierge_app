class VendorQuoteComparisonComponent < ApplicationViewComponent
  option :event_plan
  option :quotes
  option :as_of
  option :editable, default: -> { false }

  style :status_badge do
    base { %w[inline-flex rounded-full border px-2.5 py-1 text-xs font-semibold] }
    variants do
      status do
        draft { %w[border-private-line bg-canvas text-quiet-note] }
        awaiting_response { %w[border-private-line bg-surface text-quiet-note] }
        received { %w[border-primary/30 bg-surface text-primary] }
        under_review { %w[border-primary/30 bg-surface text-primary] }
        accepted { %w[border-primary/30 bg-surface text-primary] }
        declined { %w[border-private-line bg-surface text-quiet-note] }
        expired { %w[border-danger-border bg-danger-surface text-danger-ink] }
      end
    end
    defaults { { status: :draft } }
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

  style :text_action do
    base do
      %w[
        inline-flex min-h-11 items-center text-sm font-semibold text-primary underline underline-offset-4
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

  def amount_label(quote)
    amount = number_with_precision(
      BigDecimal(quote.amount_cents.to_s) / 100,
      precision: 2,
      delimiter: t("vendor_quotes.comparison.number.delimiter"),
      separator: t("vendor_quotes.comparison.number.separator")
    )
    symbol = { "USD" => "$", "CRC" => "₡", "EUR" => "€" }.fetch(quote.currency, "")
    t("vendor_quotes.comparison.amount_display", amount: "#{symbol}#{amount}", currency: quote.currency)
  end

  def status_label(quote)
    t("vendor_quotes.statuses.#{display_status(quote)}")
  end

  def display_status(quote) = quote.display_status(as_of:)

  def deadlines_for(quote)
    { decision_due_on: quote.decision_due_on, expires_on: quote.expires_on }.compact
  end

  def deadline_label(date) = l(date, format: :important_date)

  def reminder_path(quote)
    new_reminder_path(event_plan_id: event_plan.id, vendor_quote_id: quote.id)
  end
end
