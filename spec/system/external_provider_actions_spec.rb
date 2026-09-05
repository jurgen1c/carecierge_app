require "rails_helper"

RSpec.describe "Provider records", type: :system do
  it "records private manual state through responsive native forms" do
    profile = create(:relationship_profile)
    sign_in profile.user
    visit relationship_profile_external_provider_actions_path(profile)
    expect(page).to have_content("Manual records")
    expect(page).to have_content("Keep a confirmation")
    click_link "Add provider record"
    fill_in "Provider", with: "Casa Verde"
    fill_in "Source of this update", with: "Phone confirmation"
    select "Failed", from: "Reported status"
    fill_in "Failure details", with: "Call tomorrow to confirm availability"
    [ [ 1440, 1000 ], [ 768, 1024 ], [ 390, 844 ] ].each do |width, height|
      page.current_window.resize_to(width, height)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
      save_screenshot("provider-form-#{width}.png", full: true) if ENV["CAPTURE_PROVIDER_UI"] == "true"
    end
    click_button "Save record"
    expect(page).to have_content("Provider record saved.")
    expect(page).to have_content("Call tomorrow to confirm availability")
    expect(page).to have_no_button("Buy now")
    save_screenshot("provider-record-mobile.png", full: true) if ENV["CAPTURE_PROVIDER_UI"] == "true"
    click_link "Edit record"
    select "Confirmed", from: "Reported status"
    click_button "Save record"
    expect(page).to have_content("Confirmed")
    expect(page).to have_no_content("Call tomorrow to confirm availability")
    click_button "Remove local record"
    expect(page).to have_content("Nothing was cancelled with the provider")
  ensure
    page.current_window.resize_to(1280, 800)
  end
end
