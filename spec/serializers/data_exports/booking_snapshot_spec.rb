require "rails_helper"

RSpec.describe DataExports::Snapshot do
  it "exports decrypted owner booking details inside their event plan without ownership keys" do
    booking = create(
      :booking,
      title: "Private dinner",
      confirmation_details: "Confirmation PRIVATE-42",
      cancellation_policy: "Cancel by noon",
      notes: "Quiet table"
    )
    Bookings::Save.call(booking, attributes: {}, locale: :en)

    snapshot = described_class.new(
      user: booking.user,
      relationship_profile: booking.event_plan.relationship_profile,
      include_sensitive: false
    ).to_h
    exported = snapshot.dig("relationship_profiles", 0, "event_plans", 0, "bookings", 0)

    expect(exported).to include(
      "id" => booking.id,
      "title" => "Private dinner",
      "confirmation_details" => "Confirmation PRIVATE-42",
      "cancellation_policy" => "Cancel by noon",
      "notes" => "Quiet table"
    )
    expect(exported).not_to have_key("user_id")
    expect(exported).not_to have_key("event_plan_id")
    expect(exported).not_to have_key("plan_task_id")
    expect(exported).not_to have_key("lock_version")
  end
end
