require "rails_helper"

RSpec.describe AuditEventMarkerComponent, type: :component do
  it "renders the supported semantic tones through style variants" do
    render_inline(described_class.new(tone: :security))
    expect(page).to have_css("span.bg-amber-600[aria-hidden='true']")

    render_inline(described_class.new(tone: :deletion))
    expect(page).to have_css("span.bg-red-700[aria-hidden='true']")

    render_inline(described_class.new)
    expect(page).to have_css("span.bg-emerald-700[aria-hidden='true']")
  end
end
