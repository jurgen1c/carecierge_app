require "rails_helper"

RSpec.describe "Data controls", type: :system do
  it "keeps export and destructive actions clear at desktop and mobile widths" do
    user = create(:user, email: "owner@example.com")
    create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_profile, user:, preferred_name: "Elena", discarded_at: Time.current)
    sign_in user

    visit data_control_path

    expect(page).to have_css("h1", text: "Export or delete your data")
    expect(page).to have_css("h2", text: "Download your data")
    expect(page).to have_button("Download account export")
    expect(page).to have_button("Download profile export")
    expect(page).to have_select("Relationship", options: %w[Maya Elena])
    expect(page).to have_css("h2", text: "Permanent deletion")
    expect(page).to have_button("Delete AI-generated data")
    expect(page).to have_button("Delete my account")
    expect(page).to have_css("label[for='account_export_data_export_format']")
    expect(page).to have_css("label[for='profile_export_data_export_format']")
    expect(page).to have_css("form[data-turbo='false']", count: 2)

    verify_responsive_width(1440, 1000)
    save_screenshot("data-controls-desktop.png", full: true) if capture_screenshots?
    verify_responsive_width(390, 844)
    save_screenshot("data-controls-mobile.png", full: true) if capture_screenshots?
  ensure
    page.current_window.resize_to(1280, 800)
  end

  it "downloads account and profile exports through native browser navigation" do
    user = create(:user)
    create(:relationship_profile, user:, preferred_name: "Maya")
    sign_in user
    visit data_control_path

    downloads = page.driver.browser.page.downloads

    downloads.wait { click_button "Download account export" }
    expect(downloads.files).to include(
      a_hash_including("suggestedFilename" => a_string_matching(/carecierge-account-.*\.json/), "state" => "completed")
    )

    downloads.wait { click_button "Download profile export" }
    expect(downloads.files).to include(
      a_hash_including("suggestedFilename" => a_string_matching(/carecierge-relationship-profile-.*\.json/), "state" => "completed")
    )
  end

  private

  def verify_responsive_width(width, height)
    page.current_window.resize_to(width, height)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
  end

  def capture_screenshots?
    ENV["CAPTURE_DATA_CONTROLS_UI"] == "true"
  end
end
