require "rails_helper"

RSpec.describe "Professional relationship preparation", type: :system do
  it "selects work sources, retains context and exposes core follow-up and milestone paths on mobile" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    commitment = create(:commitment, relationship_profile: profile, title: "Send the work proposal")
    sign_in user
    page.driver.browser.resize(width: 390, height: 844)
    visit edit_relationship_profile_path(profile)
    select "Professional", from: "Relationship mode"
    find("summary", text: "Edit work context and sources").click
    fill_in "Organization", with: "Acme"
    fill_in "Performance review preparation", with: "Discuss delivery goals"
    check "professional_source_#{commitment.id}"
    click_button "Save profile"
    expect(page).to have_text("Acme")
    expect(page).to have_text("Discuss delivery goals")
    expect(page).to have_link("Add client milestones", href: relationship_profile_path(profile, anchor: "important_dates_section"))
    [ 390, 768, 1280 ].each do |width|
      page.driver.browser.resize(width:, height: 844)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      page.save_screenshot(File.join(ENV.fetch("CAR80_SCREENSHOTS"), "professional-#{width}.png")) if ENV["CAR80_SCREENSHOTS"]
    end
    expect(profile.reload.professional_context["commitments"]).to eq([ commitment.id ])
  end
end
