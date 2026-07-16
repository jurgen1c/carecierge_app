require "rails_helper"

RSpec.describe DispatchDueDigestsJob, type: :job do
  it "claims and enqueues the selected channel once per scheduled occurrence" do
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]
    now = zone.local(2026, 7, 15, 9, 2)
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "email",
      digest_time: "09:00",
      time_zone: zone.tzinfo.name,
      digest_schedule_changed_at: zone.local(2026, 7, 15, 8, 0)
    )

    Timecop.freeze(now) do
      expect { described_class.perform_now }
        .to change(DigestDelivery, :count).by(1)
        .and have_enqueued_job(DeliverDigestJob).once
      digest_jobs = -> { ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job[:job] == DeliverDigestJob } }
      enqueued_count = digest_jobs.call
      expect { described_class.perform_now }.not_to change(DigestDelivery, :count)
      expect(digest_jobs.call).to eq(enqueued_count)
    end

    expect(DigestDelivery.sole).to have_attributes(
      user: preference.user,
      channel: "email",
      mode: "daily",
      scheduled_for: zone.local(2026, 7, 15, 9, 0)
    )
  end

  it "defers a digest scheduled during quiet hours until they end" do
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "email",
      digest_time: "23:00",
      quiet_hours_enabled: true,
      quiet_hours_start: "22:00",
      quiet_hours_end: "07:00",
      time_zone: zone.tzinfo.name,
      digest_schedule_changed_at: zone.local(2026, 7, 15, 8, 0)
    )

    Timecop.freeze(zone.local(2026, 7, 16, 7, 2)) { described_class.perform_now }

    expect(DigestDelivery.sole).to have_attributes(
      user: preference.user,
      scheduled_for: zone.local(2026, 7, 15, 23, 0)
    )
  end

  it "recovers the latest occurrence after a modest scheduler outage" do
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "email",
      digest_time: "09:00",
      time_zone: zone.tzinfo.name,
      digest_schedule_changed_at: zone.local(2026, 7, 15, 8, 0)
    )

    Timecop.freeze(zone.local(2026, 7, 15, 10, 0)) { described_class.perform_now }

    expect(DigestDelivery.sole).to have_attributes(
      user: preference.user,
      scheduled_for: zone.local(2026, 7, 15, 9, 0)
    )
  end

  it "does not claim a digest when its selected channel is disabled" do
    create(:notification_preference, digest_mode: "daily", digest_channel: "email", email_enabled: false, digest_time: Time.current)

    expect { described_class.perform_now }.not_to change(DigestDelivery, :count)
  end

  it "does not amplify a failed delivery while Active Job owns its retries" do
    delivery = create(:digest_delivery, status: "failed", enqueued_at: nil)

    expect { described_class.perform_now }.not_to have_enqueued_job(DeliverDigestJob).with(delivery)
    expect(delivery.reload.status).to eq("failed")
  end

  it "releases a recovered delivery lease when enqueueing fails" do
    delivery = create(:digest_delivery, status: "pending", enqueued_at: 20.minutes.ago)
    allow(DeliverDigestJob).to receive(:perform_later).and_raise("queue unavailable")

    expect(DigestDelivery.recoverable(before: described_class::ENQUEUE_LEASE.ago)).to include(delivery)

    expect { described_class.perform_now }.to raise_error("queue unavailable")

    expect(delivery.reload).to have_attributes(status: "pending", enqueued_at: nil)
  end

  it "claims an earlier occurrence for the current quiet-hours end" do
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "email",
      digest_time: "09:00",
      quiet_hours_enabled: true,
      quiet_hours_start: "22:00",
      quiet_hours_end: "07:00",
      time_zone: zone.tzinfo.name,
      digest_schedule_changed_at: zone.local(2026, 7, 15, 8, 0)
    )

    now = zone.local(2026, 7, 15, 23, 0)
    deferred_until = zone.local(2026, 7, 16, 7, 0)

    Timecop.freeze(now) do
      expect { described_class.perform_now }
        .to have_enqueued_job(DeliverDigestJob).at(deferred_until)
    end

    expect(DigestDelivery.find_by!(user: preference.user)).to have_attributes(
      scheduled_for: zone.local(2026, 7, 15, 9, 0),
      enqueued_at: deferred_until
    )
  end
end
