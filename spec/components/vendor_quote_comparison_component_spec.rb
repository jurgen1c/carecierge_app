require "rails_helper"

RSpec.describe VendorQuoteComparisonComponent, type: :component do
  it "renders one semantic desktop comparison and mobile review summaries" do
    plan = create(:event_plan)
    first = create(
      :vendor_quote,
      user: plan.user,
      event_plan: plan,
      vendor: create(:vendor, user: plan.user, name: "Evergreen Events"),
      decision_due_on: Date.new(2026, 9, 18),
      expires_on: Date.new(2026, 9, 20)
    )
    second = create(:vendor_quote, user: plan.user, event_plan: plan, vendor: create(:vendor, user: plan.user, name: "Table & Thyme"), amount: "1480.00")

    render_inline(described_class.new(event_plan: plan, quotes: [ first, second ], as_of: Date.new(2026, 9, 3), editable: true))

    expect(page).to have_css("table caption.sr-only", text: "Vendor quote comparison")
    expect(page).to have_css("th[scope='col']", text: "Amount")
    expect(page).to have_css("th[scope='row']", text: "Evergreen Events")
    expect(page).to have_css("[data-mobile-quote]", count: 2)
    expect(page).to have_css("dt", text: "Decision due")
    expect(page).to have_css("dt", text: "Expires")
    expect(page).to have_content("Sep 18, 2026")
    expect(page).to have_content("Sep 20, 2026")
    routes = Rails.application.routes.url_helpers
    expect(page).to have_link("Review quote", href: routes.edit_vendor_quote_path(first))
    expect(page).to have_link("Set reminder", href: routes.new_reminder_path(event_plan_id: plan.id, vendor_quote_id: first.id))
  end

  it "uses a read-only presentation for a terminal plan" do
    quote = create(:vendor_quote, notes: "Private loading-access details")

    render_inline(described_class.new(event_plan: quote.event_plan, quotes: [ quote ], as_of: Date.new(2026, 9, 3), editable: false))

    expect(page).to have_no_link("Review quote")
    expect(page).to have_no_link("Set reminder")
    expect(page).to have_css("[data-mobile-quote]", count: 1)
    expect(page).to have_content("Private loading-access details", count: 2)
  end

  it "formats amounts with Spanish separators" do
    quote = create(:vendor_quote, amount: "1250.50")

    I18n.with_locale(:es) do
      render_inline(described_class.new(event_plan: quote.event_plan, quotes: [ quote ], as_of: Date.new(2026, 9, 3), editable: true))
    end

    expect(page).to have_content("$1.250,50 USD")
  end

  it "keeps cents exact while formatting the largest supported amount" do
    quote = create(:vendor_quote, amount_cents: VendorQuote::MAX_AMOUNT_CENTS)
    component = described_class.new(event_plan: quote.event_plan, quotes: [ quote ], as_of: Date.new(2026, 9, 3), editable: true)

    expect(component).to receive(:number_with_precision)
      .with(instance_of(BigDecimal), hash_including(precision: 2))
      .at_least(:once)
      .and_call_original

    render_inline(component)

    expect(page).to have_content("$21,474,836.47 USD")
  end
end
