require "rails_helper"

RSpec.describe "Booking management", type: :system do
  it "keeps booking logistics review-only, editable, and responsive" do
    booking = create(
      :booking,
      title: "Dinner reservation",
      provider_name: "Casa Verde",
      location: "Garden room",
      status: "requested"
    )
    Bookings::Save.call(booking, attributes: {}, locale: :en)
    sign_in booking.user

    visit event_plan_bookings_path(booking.event_plan)

    expect(page).to have_css("h1", text: "Bookings")
    [ "Dinner reservation", "Casa Verde", "Garden room", "Requested" ].each do |text|
      expect(page).to have_content(text)
    end
    expect(page).to have_content("Carecierge does not contact providers, book, purchase, pay, or message")
    expect(page).to have_no_link("Book now")
    expect(page).to have_no_button("Pay deposit")

    verify_responsive_width(1440, 1000)
    save_screenshot("bookings-desktop.png", full: true) if capture_screenshots?
    verify_responsive_width(390, 844)
    save_screenshot("bookings-mobile.png", full: true) if capture_screenshots?

    click_link "Edit booking"
    select "Confirmed", from: "Status"
    fill_in "Confirmation details", with: "Confirmation CV-42"
    click_button "Save changes"

    expect(page).to have_content("Booking updated.")
    expect(page).to have_content("Confirmed")
    expect(booking.reload).to be_confirmed
    expect(booking.plan_task).to be_completed
  ensure
    page.current_window.resize_to(1280, 800)
  end

  private

  def verify_responsive_width(width, height)
    page.current_window.resize_to(width, height)
    expect(page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")).to be(true)
  end

  def capture_screenshots?
    ENV["CAPTURE_BOOKINGS_UI"] == "true"
  end
end
