require "rails_helper"

RSpec.describe NotificationSwitchRowComponent, type: :component do
  it "renders an accessible switch with attention and availability variants" do
    preference = build(:notification_preference, push_enabled: true)
    form = ActionView::Helpers::FormBuilder.new(
      :notification_preference,
      preference,
      vc_test_controller.view_context,
      {}
    )

    render_inline(
      described_class.new(
        form:,
        field: :push_enabled,
        title: "Push notifications",
        description: "Receive mobile notifications.",
        availability: "Available later.",
        attention: true
      )
    )

    expect(page).to have_css("input[role='switch'][aria-label='Push notifications'][checked]")
    expect(page).to have_text("Needs attention")
    expect(page).to have_text("Available later.")
  end
end
