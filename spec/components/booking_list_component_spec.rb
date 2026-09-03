require "rails_helper"

RSpec.describe BookingListComponent, type: :component do
  it "renders chronological booking logistics with accessible actions" do
    plan = create(:event_plan)
    later = create(:booking, user: plan.user, event_plan: plan, title: "Late dinner", starts_at: 2.days.from_now, status: "confirmed")
    earlier = create(:booking, user: plan.user, event_plan: plan, title: "Parking", starts_at: 1.day.from_now, status: "planned")

    render_inline(described_class.new(event_plan: plan, bookings: [ earlier, later ], editable: true))

    expect(page).to have_css("section[aria-labelledby='bookings-title']")
    expect(page).to have_css("ol[data-booking-timeline]")
    expect(page.text.index("Parking")).to be < page.text.index("Late dinner")
    expect(page).to have_link("Add booking", href: Rails.application.routes.url_helpers.new_event_plan_booking_path(plan))
    expect(page).to have_link("Edit booking", href: Rails.application.routes.url_helpers.edit_booking_path(earlier))
    expect(page).to have_button("Remove booking", count: 2)
    expect(page).not_to have_button("Book")
  end

  it "keeps explicit removal available when the plan is read-only" do
    booking = create(
      :booking,
      confirmation_details: "Confirmation CV-42",
      cancellation_policy: "Cancel by noon",
      notes: "Ask about accessibility"
    )

    render_inline(described_class.new(event_plan: booking.event_plan, bookings: [ booking ], editable: false))

    expect(page).to have_no_link("Edit booking")
    expect(page).to have_button("Remove booking")
    expect(page).to have_text("Confirmation details: Confirmation CV-42")
    expect(page).to have_text("Cancellation policy: Cancel by noon")
    expect(page).to have_text("Notes: Ask about accessibility")
  end

  it "hides reminder actions that are obsolete for the booking status" do
    plan = create(:event_plan)
    confirmed = create(:booking, user: plan.user, event_plan: plan, status: "confirmed")
    completed = create(:booking, user: plan.user, event_plan: plan, status: "completed")

    render_inline(described_class.new(event_plan: plan, bookings: [ confirmed, completed ], editable: true))

    expect(page).to have_no_link("Set confirmation reminder", visible: :all)
    expect(page).to have_link("Set deposit reminder", count: 1, visible: :all)
    expect(page).to have_link("Set arrival reminder", count: 1, visible: :all)
    expect(page).to have_link("Set change reminder", count: 1, visible: :all)
    expect(page).to have_css("details", count: 1)
  end

  it "can omit its repeated introduction on the dedicated bookings page" do
    plan = create(:event_plan)
    booking = create(:booking, user: plan.user, event_plan: plan)

    render_inline(described_class.new(event_plan: plan, bookings: [ booking ], editable: true, show_header: false))

    expect(page).to have_no_css("#bookings-title")
    expect(page).to have_link("Add booking")
  end

  it "renders a concrete empty state without nested interactive controls" do
    plan = create(:event_plan)

    render_inline(described_class.new(event_plan: plan, bookings: [], editable: true))

    expect(page).to have_text("No bookings yet")
    expect(page).to have_link("Add booking", count: 1)
    expect(page).to have_no_css("a button, button a")
  end
end
