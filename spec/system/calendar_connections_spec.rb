require "rails_helper"

RSpec.describe "Calendar connections", type: :system do
  it "keeps owner choices, privacy consequences, and recovery clear at desktop and mobile widths" do
    connection = create(:calendar_connection, sync_types: [ "important_dates" ])
    sign_in connection.user

    visit calendar_connection_path

    expect(page).to have_css("h1", text: "Calendar integrations")
    expect(page).to have_css("input[role='switch']", count: CalendarConnection::SYNC_TYPES.size)
    expect(page).to have_checked_field("Important dates")
    expect(page).to have_unchecked_field("Reminders")
    expect(page).to have_button("Save sync choices")
    expect(page).to have_button("Disconnect Google Calendar")
    expect(page).to have_text("never include private notes, guest lists, confirmation details, or saved locations")

    verify_responsive_width(1440, 1000)
    save_screenshot("calendar-connections-desktop.png", full: true) if capture_screenshots?
    verify_responsive_width(390, 844)
    save_screenshot("calendar-connections-mobile.png", full: true) if capture_screenshots?
  ensure
    page.current_window.resize_to(1280, 800)
  end

  private

  def verify_responsive_width(width, height)
    page.current_window.resize_to(width, height)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
  end

  def capture_screenshots?
    ENV["CAPTURE_CALENDAR_CONNECTIONS_UI"] == "true"
  end
end
