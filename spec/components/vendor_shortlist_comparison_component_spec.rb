require "rails_helper"

RSpec.describe VendorShortlistComparisonComponent, type: :component do
  it "renders a calm source-backed comparison and explicit review-only decisions" do
    shortlist = create(:vendor_shortlist)
    vendor = create(
      :vendor,
      user: shortlist.user,
      source_kind: "external",
      source_name: "Vendor website",
      source_url: "https://example.com/vendor"
    )
    option = create(
      :vendor_option,
      vendor_shortlist: shortlist,
      vendor:,
      notes: "Good past experience.",
      constraints: "Confirm accessibility.",
      next_action: "Call after reviewing the menu."
    )

    render_inline described_class.new(shortlist:, options: [ option ], editable: true)

    expect(page).to have_css("table[aria-label='Vendor comparison']")
    [
      "Price range",
      "Availability",
      "Location",
      "Why it may fit",
      "Notes",
      "Constraints",
      "Next action",
      "Good past experience.",
      "Confirm accessibility.",
      "Call after reviewing the menu."
    ].each { |text| expect(page).to have_content(text) }
    expect(page).to have_link("Vendor website", href: "https://example.com/vendor")
    expect(page).to have_button("Mark as favorite", visible: :all)
    expect(page).to have_button("Reject option", visible: :all)
    expect(page).to have_button("Select vendor", visible: :all)
    expect(page).to have_no_button("Book")
    expect(page).to have_no_button("Contact")
    expect(page).to have_css(
      "[role='region'][tabindex='0'][aria-labelledby='vendor-comparison-title']",
      visible: :all
    )
    expect(page).to have_field("vendor_option[lock_version]", type: :hidden, with: option.lock_version, visible: :all)
    expect(page.find_button("Reject option", visible: :all)[:class]).to include("border-private-line", "text-ink")
    expect(page.find_button("Reject option", visible: :all)[:class]).not_to include("border-danger-border", "text-danger-ink")
    expect(rendered_content).to include("overflow-x-auto", "border-private-line", "focus-visible:outline-primary")
    expect(rendered_content).not_to match(/(?:emerald|red)-\d/)
  end

  it "renders selected read-only Spanish state with only explicit removal" do
    option = create(:vendor_option, decision: "selected", selected_at: Time.current)

    I18n.with_locale(:es) do
      render_inline described_class.new(
        shortlist: option.vendor_shortlist,
        options: [ option ],
        editable: false,
        removable: true
      )
    end

    expect(page).to have_content("Proveedor seleccionado")
    expect(page).to have_no_button("Seleccionar proveedor")
    expect(page).to have_button("Quitar de la lista", visible: :all)
    expect(page).to have_no_content("Translation missing")
  end

  it "uses unique field identifiers for every editable vendor option" do
    shortlist = create(:vendor_shortlist)
    options = create_list(:vendor_option, 2, vendor_shortlist: shortlist)

    render_inline described_class.new(shortlist:, options:, editable: true)

    textareas = page.all("textarea", visible: :all)
    expect(textareas.map { |textarea| textarea[:id] }).to eq(textareas.map { |textarea| textarea[:id] }.uniq)
    textareas.each do |textarea|
      expect(page).to have_css("label[for='#{textarea[:id]}']", count: 1, visible: :all)
    end
  end
end
