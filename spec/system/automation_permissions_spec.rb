require "rails_helper"

RSpec.describe "Automation permissions", type: :system do
  it "switches capability context and manages independently collapsible overrides" do
    user = create(:user)
    elena = create(:relationship_profile, user:, preferred_name: "Elena")
    marco = create(:relationship_profile, user:, preferred_name: "Marco")
    create(
      :automation_permission,
      user:,
      relationship_profile: elena,
      capability: "make_reservations",
      mode: "ask_every_time"
    )
    sign_in user

    visit edit_automation_permissions_path
    click_link "Make reservations"

    expect(page).to have_css('[data-capability-panel="make_reservations"]:not([hidden])')
    within('[data-capability-row="make_reservations"]') do
      find("label", text: "Ask every time").click
    end
    first(:button, "Save permissions").click

    expect(page).to have_content("Automation permissions saved.")
    expect(user.automation_permissions.account_defaults.find_by!(capability: "make_reservations").mode)
      .to eq("ask_every_time")

    within('[data-capability-panel="make_reservations"]') do
      find("summary", text: "Elena").click
      within("details", text: "Elena") do
        find("label", text: "Allow automatically").click
        click_button "Save override"
      end
    end

    expect(page).to have_content("Relationship override updated.")
    expect(user.automation_permissions.find_by!(relationship_profile: elena, capability: "make_reservations").mode)
      .to eq("allow_automatically")

    within('[data-capability-panel="make_reservations"]') do
      find("summary", text: "Add relationship override").click
      within("details", text: "Add relationship override") do
        select "Marco", from: "Relationship"
        select "Ask every time", from: "Permission mode"
        click_button "Add relationship override"
      end
    end

    expect(page).to have_content("Relationship override added.")
    expect(user.automation_permissions.find_by!(relationship_profile: marco, capability: "make_reservations").mode)
      .to eq("ask_every_time")

    capture_permission_screenshots if ENV["CAPTURE_AUTOMATION_PERMISSIONS_UI"] == "true"
  end

  private

  def capture_permission_screenshots
    page.current_window.resize_to(1440, 1000)
    save_screenshot("automation-permissions-desktop.png", full: true)
    page.current_window.resize_to(390, 844)
    save_screenshot("automation-permissions-mobile.png", full: true)
    page.current_window.resize_to(1280, 800)
  end
end
