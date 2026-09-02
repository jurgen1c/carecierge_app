require "rails_helper"

RSpec.describe VendorResultComponent, type: :component do
  it "renders decision details, provenance, fit, and review-only actions" do
    vendor = create(
      :vendor,
      source_kind: "external",
      source_name: "Vendor website",
      source_url: "https://example.com/bloom"
    )
    plan = create(:event_plan, user: vendor.user)

    render_inline described_class.new(vendor:, event_plan: plan)

    expect(page).to have_content("Bloom & Stem")
    expect(page).to have_content("Florist")
    expect(page).to have_content("San Jose, Costa Rica")
    expect(page).to have_content("$150.00–$450.00")
    expect(page).to have_content("Available Saturday afternoons")
    expect(page).to have_content("Why it may fit")
    expect(page).to have_link("Vendor website", href: "https://example.com/bloom")
    expect(page).to have_button("Attach to plan")
    expect(page).to have_no_button("Book")
    expect(page).to have_no_button("Contact")
    expect(rendered_content).to include("border-private-line", "text-primary")
    expect(rendered_content).not_to match(/(?:emerald|red)-\d/)
  end

  it "renders localized Spanish copy" do
    vendor = create(:vendor, source_name: nil)

    I18n.with_locale(:es) { render_inline described_class.new(vendor:) }

    expect(page).to have_content("Por qué podría encajar")
    expect(page).to have_content("Investigación personal")
    expect(page).to have_no_content("Translation missing")
  end
end
