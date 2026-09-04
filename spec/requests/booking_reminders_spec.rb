require "rails_helper"

RSpec.describe "Booking reminders", type: :request do
  it "prefills each supported milestone without creating a reminder automatically" do
    booking = create(
      :booking,
      title: "Dinner reservation",
      starts_at: Time.utc(2026, 9, 20, 1),
      time_zone: "America/Costa_Rica"
    )
    create(:notification_preference, user: booking.user, time_zone: "America/Costa_Rica")
    sign_in booking.user

    {
      "confirmation" => "Confirm Dinner reservation",
      "deposit" => "Review deposit for Dinner reservation",
      "arrival" => "Prepare to arrive for Dinner reservation",
      "change" => "Review changes for Dinner reservation"
    }.each do |milestone, title|
      expect do
        get new_reminder_path(event_plan_id: booking.event_plan_id, booking_id: booking.id, booking_milestone: milestone)
      end.not_to change(Reminder, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(title, "Booking reminder")
      expect(response.body).to include(%(value="#{booking.id}"), %(value="#{milestone}"))
    end
  end

  it "leaves the schedule blank when no useful future time exists before the booking" do
    Timecop.freeze(Time.utc(2026, 9, 20, 12, 15)) do
      booking = create(:booking, starts_at: 30.minutes.from_now, time_zone: "UTC")
      create(:notification_preference, user: booking.user, time_zone: "UTC")
      sign_in booking.user

      get new_reminder_path(
        event_plan_id: booking.event_plan_id,
        booking_id: booking.id,
        booking_milestone: "arrival"
      )

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.at_css("input[name='reminder[scheduled_at]']")&.[]("value")).to be_blank
    end
  end

  it "creates an owner-controlled milestone reminder attached to the booking and plan" do
    booking = create(:booking)
    create(:notification_preference, user: booking.user, time_zone: "UTC")
    sign_in booking.user

    post reminders_path, params: {
      reminder: {
        title: "Confirm dinner",
        scheduled_at: 1.day.from_now.strftime("%Y-%m-%dT%H:%M"),
        time_zone: "UTC",
        reminder_type: "event_preparation",
        priority: "normal",
        recurrence: "none",
        event_plan_id: booking.event_plan_id,
        booking_id: booking.id,
        booking_milestone: "confirmation"
      }
    }

    reminder = Reminder.order(:created_at).last
    expect(reminder).to have_attributes(user: booking.user, event_plan: booking.event_plan, booking:, booking_milestone: "confirmation")
    expect(reminder.relationship_profile_id).to eq(booking.event_plan.relationship_profile_id)
  end

  it "rejects foreign bookings and unsupported milestones without disclosing data" do
    user = create(:user)
    plan = create(:event_plan, user:, relationship_profile: create(:relationship_profile, user:))
    foreign_booking = create(:booking)
    sign_in user

    get new_reminder_path(event_plan_id: plan.id, booking_id: foreign_booking.id, booking_milestone: "confirmation")
    expect(response).to have_http_status(:not_found)

    get new_reminder_path(event_plan_id: plan.id, booking_id: foreign_booking.id, booking_milestone: "payment")
    expect(response).to have_http_status(:not_found)
  end

  it "nullifies the booking reference while preserving reminder history when a booking is removed" do
    booking = create(:booking)
    reminder = create(
      :reminder,
      user: booking.user,
      relationship_profile: booking.event_plan.relationship_profile,
      event_plan: booking.event_plan,
      booking:,
      booking_milestone: "arrival"
    )

    booking.destroy!

    expect(reminder.reload).to have_attributes(booking: nil, booking_milestone: nil)
  end
end
