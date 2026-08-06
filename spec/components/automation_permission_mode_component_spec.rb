require "rails_helper"

RSpec.describe AutomationPermissionModeComponent, type: :component do
  it "renders an accessible checked radio group for every allowed mode" do
    render_inline(
      described_class.new(
        name: "automation_permissions[modes][draft_messages]",
        id_prefix: "draft_messages",
        label: "Draft messages account permission",
        selected_mode: "ask_every_time",
        allowed_modes: AutomationCapability::MODES
      )
    )

    expect(page).to have_css("fieldset[aria-label='Draft messages account permission']")
    expect(page).to have_css("input[type='radio'][name='automation_permissions[modes][draft_messages]']", count: 3)
    expect(page).to have_css("input[value='ask_every_time'][checked]")
    expect(page).to have_text("Allow automatically")
  end

  it "omits automatic execution when the capability does not allow it" do
    render_inline(
      described_class.new(
        name: "automation_permissions[modes][make_purchases]",
        id_prefix: "make_purchases",
        label: "Make purchases account permission",
        selected_mode: "ask_every_time",
        allowed_modes: %w[disabled ask_every_time]
      )
    )

    expect(page).to have_css("input[type='radio']", count: 2)
    expect(page).not_to have_css("input[value='allow_automatically']")
  end
end
