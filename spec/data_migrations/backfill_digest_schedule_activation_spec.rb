require "rails_helper"
require Rails.root.join("db/data/20260716042058_backfill_digest_schedule_activation")

RSpec.describe BackfillDigestScheduleActivation do
  it "bounds active legacy schedules without changing disabled or already bounded preferences" do
    active = create(:notification_preference)
    disabled = create(:notification_preference, digest_mode: "off")
    bounded = create(:notification_preference)
    original_boundary = 1.day.ago
    active.update_columns(digest_mode: "daily", digest_schedule_changed_at: nil)
    disabled.update_column(:digest_schedule_changed_at, nil)
    bounded.update_columns(digest_mode: "weekly", digest_schedule_changed_at: original_boundary)

    described_class.new.up

    expect(active.reload.digest_schedule_changed_at).to be_present
    expect(disabled.reload.digest_schedule_changed_at).to be_nil
    expect(bounded.reload.digest_schedule_changed_at).to be_within(1.second).of(original_boundary)
  end
end
