require "rails_helper"

RSpec.describe AutomationPermissionOverrideComponent, type: :component do
  it "renders one independently collapsible, mutable relationship override" do
    profile = create(:relationship_profile, preferred_name: "Elena")
    permission = create(
      :automation_permission,
      user: profile.user,
      relationship_profile: profile,
      capability: "make_reservations",
      mode: "ask_every_time"
    )

    render_inline(described_class.new(permission:))

    expect(page).to have_css("details[data-automation-permission-override]")
    expect(page).to have_css("details > summary", text: "Elena")
    expect(page).to have_css("details form", count: 2, visible: :all)
    expect(page).to have_css(
      "input[name='automation_permission[mode]'][value='ask_every_time'][checked]",
      visible: :all
    )
    expect(page).to have_button("Save override", visible: :all)
    expect(page).to have_button("Remove override", visible: :all)
  end
end
