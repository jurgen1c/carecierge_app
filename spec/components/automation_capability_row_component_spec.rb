require "rails_helper"

RSpec.describe AutomationCapabilityRowComponent, type: :component do
  it "renders a selectable account permission row with its risk and override count" do
    capability = AutomationCapability.fetch(:make_reservations)

    render_inline(
      described_class.new(
        capability:,
        selected_mode: "ask_every_time",
        selected: true,
        override_count: 2
      )
    )

    expect(page).to have_css('[data-automation-permissions-target="row"][data-selected="true"]')
    permission_path = Rails.application.routes.url_helpers.edit_automation_permissions_path(capability: capability.key)
    expect(page).to have_link("Make reservations", href: permission_path)
    expect(page).to have_text("Medium risk")
    expect(page).to have_text("2 relationship overrides")
    expect(page).to have_css("input[name='automation_permissions[modes][make_reservations]']", count: 3)
  end

  it "does not render automatic execution for high-impact rows" do
    capability = AutomationCapability.fetch(:make_purchases)

    render_inline(
      described_class.new(
        capability:,
        selected_mode: "ask_every_time",
        selected: false,
        override_count: 0
      )
    )

    expect(page).to have_css("input[type='radio']", count: 2)
    expect(page).not_to have_css("input[value='allow_automatically']")
  end
end
