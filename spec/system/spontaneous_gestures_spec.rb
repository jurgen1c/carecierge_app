require "rails_helper"

RSpec.describe "Spontaneous gestures", type: :system do
  it "rotates, saves, and completes gestures at desktop and mobile widths" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya", type: "RelationshipProfiles::Friend")
    sign_in user

    visit relationship_profile_path(profile, suggestion_type: "spontaneous")

    within("#suggestions_section") do
      expect(page).to have_text("Low effort")
      expect(page).to have_text("Send Maya a quick voice note")
      expect(page).to have_button("Save")
      expect(page).to have_button("Mark complete")
      expect(page).to have_link("Show another")
    end
    verify_responsive_width(1440, 1000)
    verify_responsive_width(390, 844)

    within("#suggestions_section") { click_link "Show another" }
    within("#suggestions_section") do
      expect(page).to have_text("Medium effort")
      expect(page).to have_text("Bring Maya a thoughtful extra")
      click_button "Save"
      expect(page).to have_button("Saved", disabled: true)
      click_button "Mark complete"
      expect(page).to have_text("No suggestions right now")
    end
  ensure
    page.current_window.resize_to(1280, 800)
  end

  private

  def verify_responsive_width(width, height)
    page.current_window.resize_to(width, height)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
  end
end
