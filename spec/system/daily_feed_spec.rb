require "rails_helper"

RSpec.describe "Concierge Queue", type: :system do
  it "keeps source-backed priorities actionable at desktop and mobile widths" do
    now = Time.zone.local(2026, 8, 14, 9)
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Taylor")
    reminder = create(
      :reminder,
      user:,
      relationship_profile: profile,
      title: "Follow up with Taylor",
      notes: "Ask how the new role is going.",
      scheduled_at: now - 1.day
    )
    create(:gift, relationship_profile: profile, name: "Graduation photo book")
    sign_in user

    Timecop.freeze(now) do
      visit dashboard_path

      expect(page).to have_css("h1", text: "Concierge queue")
      expect(page).to have_css("h2", text: "Needs attention")
      expect(page).to have_css("h2", text: "Later today")
      expect(page).to have_css("h2", text: "Coming up")
      expect(page).to have_content("Follow up with Taylor")
      expect(page).to have_content("Ask how the new role is going.")
      expect(page).to have_button("Complete")
      expect(page).to have_button("Snooze")
      expect(page).to have_button("Dismiss")

      verify_responsive_width(1440, 1000)
      save_screenshot("daily-feed-desktop.png", full: true) if capture_screenshots?
      verify_responsive_width(390, 844)
      expect(page).to have_css("details summary", text: "Menu")
      save_screenshot("daily-feed-mobile.png", full: true) if capture_screenshots?

      within("[data-feed-item-key='reminder:#{reminder.id}']") { click_button "Snooze" }
      expect(page).to have_content("The item will return tomorrow morning.")
      expect(page).not_to have_content("Follow up with Taylor")
      expect(reminder.reload).to be_active
    end
  ensure
    page.current_window.resize_to(1280, 800)
  end

  private

  def verify_responsive_width(width, height)
    page.current_window.resize_to(width, height)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
  end

  def capture_screenshots?
    ENV["CAPTURE_DAILY_FEED_UI"] == "true"
  end
end
