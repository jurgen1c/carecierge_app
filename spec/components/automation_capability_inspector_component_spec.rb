require "rails_helper"

RSpec.describe AutomationCapabilityInspectorComponent, type: :component do
  it "explains the capability and renders independently collapsible override editors" do
    user = create(:user)
    overridden_profile = create(:relationship_profile, user:, preferred_name: "Elena")
    available_profile = create(:relationship_profile, user:, preferred_name: "Marco")
    override = create(
      :automation_permission,
      user:,
      relationship_profile: overridden_profile,
      capability: "make_reservations",
      mode: "ask_every_time"
    )

    render_inline(
      described_class.new(
        capability: AutomationCapability.fetch(:make_reservations),
        overrides: [ override ],
        relationship_profiles: [ overridden_profile, available_profile ],
        selected: true
      )
    )

    expect(page).to have_css('[data-capability-panel="make_reservations"]:not([hidden])')
    expect(page).to have_text("Calendar")
    expect(page).to have_css("details[data-automation-permission-override]", count: 1)
    expect(page).to have_select("Relationship", with_options: [ "Marco" ], visible: :all)
    expect(page).to have_css("#make_reservations_automation_permission_relationship_profile_id", visible: :all)
    expect(page).to have_css("#make_reservations_automation_permission_mode", visible: :all)
    expect(page).not_to have_css('input[name^="automation_permissions[modes]"]')
  end
end
