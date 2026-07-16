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

  it "retries when the digest processing lock is busy" do
    delivery = create(:digest_delivery)
    event = DigestEmailNotifier.with(
      record: delivery,
      mode: delivery.mode,
      digest_snapshot: { mode: "daily", as_of: Time.current.iso8601, items: [] }
    ).deliver(delivery.user, enqueue_job: false)
    allow(delivery).to receive(:with_processing_lock).and_return(false)

    expect { described_class.perform_now(event.notifications.sole) }
      .to have_enqueued_job(described_class)
  end

  it "defers the final email send when the queue reaches quiet hours" do
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]
    now = zone.local(2026, 7, 15, 22, 30)
    deferred_until = zone.local(2026, 7, 16, 7, 0)
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "email",
      quiet_hours_enabled: true,
      quiet_hours_start: "22:00",
      quiet_hours_end: "07:00",
      time_zone: zone.tzinfo.name
    )
    delivery = create(:digest_delivery, user: preference.user)
    profile = create(:relationship_profile, user: preference.user)
    create(:commitment, relationship_profile: profile, due_on: now.to_date)
    digest = Digests::Compose.call(user: preference.user, as_of: now, mode: "daily")
    event = DigestEmailNotifier.with(
      record: delivery,
      mode: delivery.mode,
      digest_snapshot: Digests::Snapshot.dump(digest)
    ).deliver(delivery.user, enqueue_job: false)

    Timecop.freeze(now) do
      delivery_count = ActionMailer::Base.deliveries.count
      expect { described_class.perform_now(event.notifications.sole) }
        .to have_enqueued_job(described_class).at(deferred_until)
      expect(ActionMailer::Base.deliveries.count).to eq(delivery_count)
    end
  end

  it "cancels the final email send after the user opts out" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "email",
      digest_schedule_changed_at: now - 1.hour
    )
    profile = create(:relationship_profile, user: preference.user)
    create(:commitment, relationship_profile: profile, due_on: now.to_date)
    delivery = create(:digest_delivery, user: preference.user, scheduled_for: now, mode: "daily", channel: "email")
    digest = Digests::Compose.call(user: preference.user, as_of: now, mode: "daily")
    event = DigestEmailNotifier.with(record: delivery, mode: delivery.mode, digest_snapshot: Digests::Snapshot.dump(digest))
      .deliver(delivery.user, enqueue_job: false)
    preference.update!(digest_mode: "off")

    expect { described_class.perform_now(event.notifications.sole) }
      .not_to change(ActionMailer::Base.deliveries, :count)
    expect(delivery.reload.status).to eq("cancelled")
  end

  it "skips the final email when every snapshotted relationship is now muted" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "email",
      digest_schedule_changed_at: now - 1.hour
    )
    profile = create(:relationship_profile, user: preference.user)
    create(:commitment, relationship_profile: profile, due_on: now.to_date)
    delivery = create(:digest_delivery, user: preference.user, scheduled_for: now, mode: "daily", channel: "email")
    digest = Digests::Compose.call(user: preference.user, as_of: now, mode: "daily")
    event = DigestEmailNotifier.with(record: delivery, mode: delivery.mode, digest_snapshot: Digests::Snapshot.dump(digest))
      .deliver(delivery.user, enqueue_job: false)
    create(:relationship_notification_preference, notification_preference: preference, relationship_profile: profile)

    expect { described_class.perform_now(event.notifications.sole) }
      .not_to change(ActionMailer::Base.deliveries, :count)
    expect(delivery.reload.status).to eq("skipped")
  end
end
