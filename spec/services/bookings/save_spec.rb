require "rails_helper"

RSpec.describe Bookings::Save do
  it "creates a booking, booking-owned task, and relationship timeline entry atomically" do
    plan = create(:event_plan)
    booking = plan.user.bookings.new(
      event_plan: plan,
      booking_kind: "reservation",
      title: "Dinner reservation",
      provider_name: "Casa Verde",
      starts_at: Time.zone.local(2026, 9, 20, 19),
      time_zone: "America/Costa_Rica",
      status: "requested"
    )

    expect do
      expect do
        expect { described_class.call(booking, attributes: {}, locale: :en) }.to change(Booking, :count).by(1)
      end.to change(PlanTask, :count).by(1)
    end.to change(TimelineEntry, :count).by(1)

    expect(booking.plan_task).to have_attributes(
      event_plan: plan,
      title: "Confirm booking: Dinner reservation",
      kind: "vendor_need",
      phase: "arrange",
      due_on: Date.new(2026, 9, 20),
      origin: "manual",
      completed_at: nil
    )
    expect(booking.timeline_entry).to have_attributes(
      relationship_profile: plan.relationship_profile,
      source_record: booking,
      entry_type: "booking",
      origin: "system",
      title: "Booking status",
      occurred_at: booking.starts_at
    )
    expect(booking.timeline_entry.body).to eq("Requested")
  end

  it "updates the plan task and timeline entry while honoring optimistic revisions" do
    booking = create(:booking, status: "requested")
    described_class.call(booking, attributes: {}, locale: :en)
    rendered_version = booking.lock_version

    expect do
      described_class.call(
        booking,
        attributes: { title: "Dinner confirmed", status: "confirmed", starts_at: Time.zone.local(2026, 9, 21, 20) },
        expected_lock_version: rendered_version,
        locale: :en
      )
    end.to change { booking.event_plan.reload.generation_version }.by(1)

    expect(booking.reload).to have_attributes(title: "Dinner confirmed", status: "confirmed")
    expect(booking.plan_task).to be_completed
    expect(booking.plan_task).to have_attributes(title: "Confirm booking: Dinner confirmed", due_on: Date.new(2026, 9, 21))
    expect(booking.timeline_entry).to have_attributes(title: "Booking status", occurred_at: booking.starts_at)
    expect(booking.timeline_entry.body).to eq("Confirmed")

    stale_version = rendered_version
    expect do
      described_class.call(booking, attributes: { notes: "Stale overwrite" }, expected_lock_version: stale_version, locale: :en)
    end.to raise_error(ActiveRecord::StaleObjectError)
  end

  it "keeps its derived plan task valid for a maximum-length private title" do
    booking = build(:booking, title: "T" * Booking::MAX_TITLE_LENGTH)

    expect { described_class.call(booking, attributes: {}, locale: :en) }
      .to change(Booking, :count).by(1)

    expect(booking.plan_task.title.length).to eq(PlanTask::MAX_TITLE_LENGTH)
    expect(booking.plan_task).to be_valid
  end

  it "reopens only its own generated task when a terminal booking becomes active again" do
    booking = create(:booking, status: "confirmed")
    described_class.call(booking, attributes: {}, locale: :en)
    expect(booking.plan_task).to be_completed

    described_class.call(
      booking,
      attributes: { status: "requested" },
      expected_lock_version: booking.lock_version,
      locale: :en
    )

    expect(booking.plan_task.reload).not_to be_completed
  end

  it "retires task reminders when booking status completes the generated task" do
    booking = create(:booking, status: "requested")
    described_class.call(booking, attributes: {}, locale: :en)
    reminder = create(
      :reminder,
      user: booking.user,
      relationship_profile: booking.event_plan.relationship_profile,
      event_plan: booking.event_plan,
      plan_task: booking.plan_task
    )

    described_class.call(
      booking,
      attributes: { status: "confirmed" },
      expected_lock_version: booking.lock_version,
      locale: :en
    )

    expect(reminder.reload).to have_attributes(status: "completed", completed_at: be_present, next_delivery_at: nil)
  end

  it "retires booking reminders when their milestones become obsolete" do
    booking = create(:booking, status: "requested")
    described_class.call(booking, attributes: {}, locale: :en)
    confirmation = create(
      :reminder,
      user: booking.user,
      relationship_profile: booking.event_plan.relationship_profile,
      event_plan: booking.event_plan,
      booking:,
      booking_milestone: "confirmation"
    )
    arrival = create(
      :reminder,
      user: booking.user,
      relationship_profile: booking.event_plan.relationship_profile,
      event_plan: booking.event_plan,
      booking:,
      booking_milestone: "arrival"
    )

    described_class.call(
      booking,
      attributes: { status: "confirmed" },
      expected_lock_version: booking.lock_version,
      locale: :en
    )

    expect(confirmation.reload).to be_completed
    expect(arrival.reload).to be_active

    described_class.call(
      booking,
      attributes: { status: "completed" },
      expected_lock_version: booking.lock_version,
      locale: :en
    )

    expect(arrival.reload).to be_completed
  end

  it "rolls back every derived record when booking persistence fails" do
    plan = create(:event_plan)
    booking = plan.user.bookings.new(event_plan: plan, title: "", provider_name: "", starts_at: nil)

    expect do
      expect do
        expect { described_class.call(booking, attributes: {}, locale: :en) }.to raise_error(ActiveRecord::RecordInvalid)
      end.not_to change(PlanTask, :count)
    end.not_to change(TimelineEntry, :count)
  end
end
