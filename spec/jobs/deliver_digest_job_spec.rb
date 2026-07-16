require "rails_helper"

RSpec.describe DeliverDigestJob, type: :job do
  it "hands a composed email to the durable queue and records completion" do
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

    Timecop.freeze(now) do
      expect { described_class.perform_now(delivery) }.to have_enqueued_job(DeliverDigestEmailJob).once
    end

    expect(delivery.reload).to have_attributes(status: "dispatched", dispatched_at: now)
  end

  it "creates an in-app notification when that channel is selected" do
    now = Time.zone.local(2026, 7, 15, 9, 0)
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "in_app",
      digest_schedule_changed_at: now - 1.hour
    )
    profile = create(:relationship_profile, user: preference.user)
    commitment = create(:commitment, relationship_profile: profile, due_on: now.to_date)
    delivery = create(:digest_delivery, user: preference.user, scheduled_for: now, mode: "daily", channel: "in_app")

    expect { described_class.perform_now(delivery) }.to change(preference.user.notifications, :count).by(1)
    expect(preference.user.notifications.last.message).to include("relationship digest")
    expect(preference.user.notifications.last.message).to include(commitment.title)
  end

  it "recovers a marked email handoff when the first queue attempt fails" do
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
    handoffs = 0
    allow(DeliverDigestEmailJob).to receive(:perform_later) do
      handoffs += 1
      raise StandardError, "queue unavailable"
    end

    Timecop.freeze(now) do
      expect { described_class.perform_now(delivery) }
        .to have_enqueued_job(described_class).with(delivery)
    end

    expect(delivery.reload.handed_off_at).to eq(now)

    allow(DeliverDigestEmailJob).to receive(:perform_later) { handoffs += 1 }
    described_class.perform_now(delivery)

    expect(handoffs).to eq(2)
    expect(delivery.reload.status).to eq("dispatched")
  end

  it "skips empty digests without sending noise" do
    preference = create(:notification_preference, digest_mode: "daily", digest_channel: "email")
    delivery = create(:digest_delivery, user: preference.user, mode: "daily", channel: "email")

    expect { described_class.perform_now(delivery) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(delivery.reload.status).to eq("skipped")
  end

  it "cancels delivery when the preference or selected channel changed after dispatch" do
    preference = create(:notification_preference, digest_mode: "daily", digest_channel: "email")
    delivery = create(:digest_delivery, user: preference.user, mode: "daily", channel: "email")
    preference.update!(digest_channel: "in_app")

    described_class.perform_now(delivery)

    expect(delivery.reload.status).to eq("cancelled")
  end

  it "cancels a queued occurrence when its schedule changes before delivery" do
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

    Timecop.freeze(now + 1.minute) { preference.update!(digest_time: "10:00") }

    expect { described_class.perform_now(delivery) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(delivery.reload.status).to eq("cancelled")
  end

  it "rechecks an opt-out immediately before notification handoff" do
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
    allow(Digests::Compose).to receive(:call) do
      preference.update!(digest_mode: "off")
      digest
    end

    expect { described_class.perform_now(delivery) }.not_to have_enqueued_job(DeliverDigestEmailJob)
    expect(delivery.reload.status).to eq("cancelled")
  end

  it "composes an overnight quiet-hour deferral for its effective delivery date" do
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]
    occurrence = zone.local(2026, 7, 15, 23, 0)
    delivery_time = zone.local(2026, 7, 16, 7, 0)
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "email",
      digest_time: "23:00",
      quiet_hours_enabled: true,
      quiet_hours_start: "22:00",
      quiet_hours_end: "07:00",
      time_zone: zone.tzinfo.name,
      digest_schedule_changed_at: occurrence - 1.hour
    )
    profile = create(:relationship_profile, user: preference.user)
    create(:commitment, relationship_profile: profile, title: "July 16 action", due_on: delivery_time.to_date)
    delivery = create(:digest_delivery, user: preference.user, scheduled_for: occurrence, mode: "daily", channel: "email")

    Timecop.freeze(delivery_time) { described_class.perform_now(delivery) }

    snapshot = DigestEmailNotifier.find_by!(record: delivery).params.with_indifferent_access.fetch(:digest_snapshot)
    titles = snapshot.with_indifferent_access.fetch(:items).map { |item| item.with_indifferent_access.fetch(:title) }
    expect(titles).to include("July 16 action")
  end

  it "defers a queued digest that reaches delivery during quiet hours" do
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
      time_zone: zone.tzinfo.name,
      digest_schedule_changed_at: now - 1.day
    )
    delivery = create(:digest_delivery, user: preference.user, scheduled_for: now - 1.hour, mode: "daily", channel: "email")

    Timecop.freeze(now) do
      email_job_count = ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job[:job] == DeliverDigestEmailJob }
      expect { described_class.perform_now(delivery) }
        .to have_enqueued_job(described_class).with(delivery).at(deferred_until)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.count { |job| job[:job] == DeliverDigestEmailJob }).to eq(email_job_count)
    end

    expect(delivery.reload).to have_attributes(status: "pending", enqueued_at: deferred_until)
  end

  it "composes a recovered quiet-hours delivery using its deferred calendar date" do
    zone = ActiveSupport::TimeZone["America/Costa_Rica"]
    occurrence = zone.local(2026, 7, 15, 9, 0)
    delivery_time = zone.local(2026, 7, 16, 7, 0)
    preference = create(
      :notification_preference,
      digest_mode: "daily",
      digest_channel: "email",
      quiet_hours_enabled: true,
      quiet_hours_start: "22:00",
      quiet_hours_end: "07:00",
      time_zone: zone.tzinfo.name,
      digest_schedule_changed_at: occurrence - 1.hour
    )
    profile = create(:relationship_profile, user: preference.user)
    create(:commitment, relationship_profile: profile, title: "Deferred-day action", due_on: delivery_time.to_date)
    delivery = create(
      :digest_delivery,
      user: preference.user,
      scheduled_for: occurrence,
      enqueued_at: delivery_time,
      mode: "daily",
      channel: "email"
    )

    Timecop.freeze(delivery_time) { described_class.perform_now(delivery) }

    snapshot = DigestEmailNotifier.find_by!(record: delivery).params.with_indifferent_access.fetch(:digest_snapshot)
    titles = snapshot.with_indifferent_access.fetch(:items).map { |item| item.with_indifferent_access.fetch(:title) }
    expect(titles).to include("Deferred-day action")
  end
end
