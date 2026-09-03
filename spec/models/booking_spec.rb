require "rails_helper"

# == Schema Information
#
# Table name: bookings
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  booking_kind         :string           default("reservation"), not null
#  cancellation_policy  :text
#  confirmation_details :text
#  location             :text
#  lock_version         :integer          default(0), not null
#  notes                :text
#  provider_name        :text             not null
#  starts_at            :datetime         not null
#  status               :string           default("planned"), not null
#  time_zone            :string           default("UTC"), not null
#  title                :text             not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  event_plan_id        :uuid             not null
#  plan_task_id         :uuid
#  user_id              :uuid             not null
#
# Indexes
#
#  index_bookings_on_event_plan_id                           (event_plan_id)
#  index_bookings_on_event_plan_id_and_starts_at_and_id      (event_plan_id,starts_at,id)
#  index_bookings_on_event_plan_id_and_status_and_starts_at  (event_plan_id,status,starts_at)
#  index_bookings_on_unique_plan_task                        (plan_task_id) UNIQUE WHERE (plan_task_id IS NOT NULL)
#  index_bookings_on_user_id                                 (user_id)
#  index_bookings_on_user_id_and_created_at                  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (plan_task_id => plan_tasks.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
RSpec.describe Booking, type: :model do
  it "normalizes and encrypts private booking logistics" do
    booking = create(
      :booking,
      title: "  Dinner reservation  ",
      provider_name: "  Casa Verde  ",
      location: "  Window table  ",
      confirmation_details: "  Confirmation CV-42  ",
      cancellation_policy: "  Cancel by noon.  ",
      notes: "  Ask about accessibility.  "
    )
    stored = described_class.connection.select_one(
      "SELECT title, provider_name, location, confirmation_details, cancellation_policy, notes FROM bookings WHERE id = #{described_class.connection.quote(booking.id)}"
    )

    expect(booking).to have_attributes(
      title: "Dinner reservation",
      provider_name: "Casa Verde",
      location: "Window table",
      confirmation_details: "Confirmation CV-42",
      cancellation_policy: "Cancel by noon.",
      notes: "Ask about accessibility."
    )
    expect(stored.values).not_to include(
      booking.title,
      booking.provider_name,
      booking.location,
      booking.confirmation_details,
      booking.cancellation_policy,
      booking.notes
    )
  end

  it "requires bounded supported fields and a recognized time zone" do
    booking = build(
      :booking,
      booking_kind: "lead",
      title: " ",
      provider_name: " ",
      starts_at: nil,
      time_zone: "Mars/Olympus",
      status: "paid"
    )

    expect(booking).not_to be_valid
    expect(booking.errors.of_kind?(:booking_kind, :inclusion)).to be(true)
    expect(booking.errors.of_kind?(:title, :blank)).to be(true)
    expect(booking.errors.of_kind?(:provider_name, :blank)).to be(true)
    expect(booking.errors.of_kind?(:starts_at, :blank)).to be(true)
    expect(booking.errors.of_kind?(:time_zone, :invalid)).to be(true)
    expect(booking.errors.of_kind?(:status, :inclusion)).to be(true)
  end

  it "rejects another owner's plan and new records for inactive plans" do
    owner = create(:user)
    foreign_plan = create(:event_plan)
    booking = build(:booking, user: owner, event_plan: foreign_plan)

    expect(booking).not_to be_valid
    expect(booking.errors.of_kind?(:event_plan, :different_owner)).to be(true)

    owned_plan = create(:event_plan, user: owner, relationship_profile: create(:relationship_profile, user: owner))
    owned_plan.complete!
    booking.event_plan = owned_plan
    expect(booking).not_to be_valid
    expect(booking.errors.of_kind?(:event_plan, :inactive)).to be(true)
  end

  it "orders upcoming logistics before past records using the scheduled instant" do
    plan = create(:event_plan)
    later = create(:booking, user: plan.user, event_plan: plan, starts_at: 3.days.from_now)
    earlier = create(:booking, user: plan.user, event_plan: plan, starts_at: 1.day.from_now)
    recent_history = create(:booking, user: plan.user, event_plan: plan, starts_at: 1.day.ago)
    older_history = create(:booking, user: plan.user, event_plan: plan, starts_at: 3.days.ago)

    expect(plan.bookings.ordered).to eq([ earlier, later, recent_history, older_history ])
  end

  it "suggests reminder times only when they remain useful before the booking" do
    Timecop.freeze(Time.utc(2026, 9, 20, 12, 15)) do
      soon = build(:booking, starts_at: 30.minutes.from_now, time_zone: "UTC")
      later = build(:booking, starts_at: 3.hours.from_now, time_zone: "UTC")

      expect(soon.suggested_reminder_at(milestone: "arrival", time_zone: "UTC")).to be_nil
      expect(later.suggested_reminder_at(milestone: "arrival", time_zone: "UTC"))
        .to eq(Time.utc(2026, 9, 20, 14, 15))
      expect(later.suggested_reminder_at(milestone: "payment", time_zone: "UTC")).to be_nil
    end
  end

  it "localizes the booking model name in both supported locales" do
    expect(I18n.with_locale(:en) { described_class.model_name.human }).to eq("Booking")
    expect(I18n.with_locale(:es) { described_class.model_name.human }).to eq("Reserva")
  end
end
