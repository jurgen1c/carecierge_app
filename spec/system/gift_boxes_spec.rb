require "rails_helper"
RSpec.describe "Gift box builder", type: :system do
  it "assembles items and prepares a reminder with responsive accessible controls" do
    profile = create(:relationship_profile)
    sign_in profile.user
    visit relationship_profile_gift_boxes_path(profile)
    within_fieldset "The occasion and budget" do
      fill_in "Name", with: "Reading box"
      fill_in "Occasion", with: "Birthday"
      fill_in "Budget", with: "40.25"
    end
    within_fieldset "Item 1" do
      fill_in "Name", with: "A useful book"
      fill_in "Item cost", with: "20.25"
      check "Purchased"
    end
    click_button "Save gift box"
    expect(page).to have_content("Gift box saved.")
    expect(page).to have_content("Known total: 20.25 USD")
    within_fieldset "Item 1" do
      check "Ready for the box"
    end
    click_button "Save gift box"
    expect(profile.gift_boxes.sole.items.sole).to be_completed
    [ [ 1440, 1000 ], [ 768, 1024 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
      save_screenshot("gift-box-#{width}.png", full: true) if ENV["CAPTURE_GIFT_BOX_UI"] == "true"
    end
    click_link "Prepare delivery reminder"
    expect(page).to have_field("Reminder", with: "Check gift box delivery: Reading box")
    expect(Reminder.count).to eq(0)
  ensure
    page.current_window.resize_to(1280, 800)
  end
end
