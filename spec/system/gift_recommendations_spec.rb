require "rails_helper"

RSpec.describe "Gift recommendation workspace", type: :system do
  it "keeps recommendations explainable, review-only, actionable, and responsive" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    recommendation = create(
      :gift_recommendation,
      user:,
      relationship_profile: profile,
      title: "Light-roast tasting set",
      estimated_price_cents: 4_000,
      vendor: "Local roaster"
    )
    sign_in user

    visit relationship_profile_path(profile, anchor: "gift-recommendations")

    within("#gift-recommendations") do
      expect(page).to have_content("Nothing is purchased automatically")
      expect(page).to have_content("Light-roast tasting set")
      expect(page).to have_content("$40.00")
      expect(page).to have_button("Save idea")
      expect(page).to have_button("Mark purchased")
      expect(page).to have_button("Try an alternative")
      expect(page).to have_button("Dismiss")
      expect(page).to have_no_link("Buy now")
    end

    verify_responsive_width(1440, 1000)
    save_screenshot("gift-recommendations-desktop.png", full: true) if capture_screenshots?
    verify_responsive_width(390, 844)
    save_screenshot("gift-recommendations-mobile.png", full: true) if capture_screenshots?

    within("#gift-recommendations") { click_button "Save idea" }
    expect(recommendation.reload).to be_saved
    expect(profile.gifts.reload.find_by(name: "Light-roast tasting set")).to be_present
    within("#gift-recommendations") { expect(page).to have_content("Saved to gift ideas") }
  ensure
    page.current_window.resize_to(1280, 800)
  end

  private

  def verify_responsive_width(width, height)
    page.current_window.resize_to(width, height)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
  end

  def capture_screenshots?
    ENV["CAPTURE_GIFT_RECOMMENDATIONS_UI"] == "true"
  end
end
