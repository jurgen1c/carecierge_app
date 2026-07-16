require "rails_helper"

RSpec.describe DeliverDigestEmailJob, type: :job do
  it "executes a committed digest email notification" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "email",
      digest_schedule_changed_at: now - 1.hour
    )
    profile = create(:relationship_profile, user: preference.user)
    commitment = create(:commitment, relationship_profile: profile, title: "Keep the original action", due_on: now.to_date)
    delivery = create(:digest_delivery, user: preference.user, scheduled_for: now, mode: "daily", channel: "email")
    digest = Digests::Compose.call(user: preference.user, as_of: now, mode: "daily")
    event = DigestEmailNotifier.with(record: delivery, mode: delivery.mode, digest_snapshot: Digests::Snapshot.dump(digest))
      .deliver(delivery.user, enqueue_job: false)
    commitment.destroy!

    notification = event.notifications.sole
    expect { described_class.perform_now(notification) }
      .to change(ActionMailer::Base.deliveries, :count).by(1)
    expect(ActionMailer::Base.deliveries.last.body.encoded).to include("Keep the original action")
    expect { described_class.perform_now(notification) }.not_to change(ActionMailer::Base.deliveries, :count)
  end
end
