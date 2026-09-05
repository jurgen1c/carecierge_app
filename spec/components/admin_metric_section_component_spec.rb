require "rails_helper"

RSpec.describe AdminMetricSectionComponent, type: :component do
  it "renders labeled counts, empty dates and localized dates" do
    render_inline(described_class.new(section: "approvals", metrics: { approval_waiting: 1_200, approval_oldest: nil }))
    expect(page).to have_css('section[aria-labelledby="approvals-heading"] h2', text: "Approval backlog")
    expect(page).to have_css('dd[data-metric="approval_waiting"]', text: "1,200")
    expect(page).to have_css('dd[data-metric="approval_oldest"]', text: "None waiting")

    I18n.with_locale(:es) do
      render_inline(described_class.new(section: "approvals", metrics: { approval_oldest: Time.utc(2026, 9, 5) }))
      expect(page).to have_text(I18n.l(Date.new(2026, 9, 5), format: :audit_event_day))
    end
  end
end
