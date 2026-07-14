require "rails_helper"

RSpec.describe "Reminder workspace", type: :system do
  it "creates and completes a relationship reminder through Turbo" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Elena")
    create(:reminder, user:, relationship_profile: profile, title: "Overdue call", scheduled_at: 1.hour.ago)
    create(:reminder, user:, relationship_profile: profile, title: "Plan weekend lunch", scheduled_at: 2.days.from_now)
    sign_in user

    visit reminders_path(relationship_profile_id: profile.id)

    expect(page).to have_css("h1", text: "Elena")
    expect(page).to have_content("Overdue call")
    expect(page).to have_content("Plan weekend lunch")
    capture_workspace_screenshots if ENV["CAPTURE_REMINDERS_UI"] == "true"

    expect(page).not_to have_css("turbo-frame#new_reminder form")
    click_link "Create reminder"
    expect(page).to have_css("turbo-frame#new_reminder form")

    within("turbo-frame#new_reminder") do
      fill_in "Reminder", with: "Send a thoughtful note"
      select "Elena", from: "Relationship"
      click_button "Create reminder"
    end

    reminder = user.reminders.find_by!(title: "Send a thoughtful note")
    expect(page).to have_content("Reminder created.")
    expect(page).to have_content(reminder.title)

    within("turbo-frame#reminder_#{reminder.id}") { click_button "Complete" }

    expect(page).to have_content("Reminder completed.")
    expect(page).not_to have_content(reminder.title)
  end

  private

  def capture_workspace_screenshots
    page.current_window.resize_to(1440, 1000)
    expect(page.evaluate_script("window.innerWidth")).to be >= 1024
    save_screenshot("reminders-desktop.png", full: true)
    page.current_window.resize_to(390, 844)
    expect(page.evaluate_script("window.innerWidth")).to be < 1024
    save_screenshot("reminders-mobile.png", full: true)
    page.current_window.resize_to(1280, 800)
  end
end
