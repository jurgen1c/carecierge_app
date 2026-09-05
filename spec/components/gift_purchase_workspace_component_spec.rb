require "rails_helper"

RSpec.describe GiftPurchaseWorkspaceComponent, type: :component do
  it "renders the complete unsaved form without requiring JavaScript and labels every option" do
    gift = build_stubbed(:gift)
    plan = GiftPurchasePlan.new(gift:)
    render_inline described_class.new(gift:, purchase_plan: plan, event_plans: [])
    expect(page).to have_button("Save purchase plan")
    expect(page).to have_field("Budget")
    expect(page).to have_css("fieldset legend", text: "Option", count: 3)
    expect(page).to have_no_link("Prepare purchase reminder")
    expect(page).to have_content("Save your purchase plan")
    expect(page).to have_css("input[type='hidden'][value='new']", visible: :all)
  end
end
