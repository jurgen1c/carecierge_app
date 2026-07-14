require "rails_helper"

RSpec.describe DispatchDueRemindersJob, type: :job do
  it "claims each enabled channel once and queues channel delivery" do
    now = Time.zone.local(2026, 7, 14, 9, 0)
    reminder = create(:reminder, scheduled_at: now - 5.minutes, next_delivery_at: now - 5.minutes)

    Timecop.freeze(now) do
      expect { described_class.perform_now }
        .to change(ReminderDelivery, :count).by(2)
        .and have_enqueued_job(DeliverReminderJob).exactly(:twice)
    end

    expect(reminder.reload.next_delivery_at).to be_nil
    expect(reminder.reminder_deliveries.pluck(:channel)).to contain_exactly("in_app", "email")

    expect { described_class.perform_now }.not_to change(ReminderDelivery, :count)
  end

  it "keeps pending delivery claims durable and recovers them after enqueue failure" do
    now = Time.zone.local(2026, 7, 14, 9, 0)
    reminder = create(:reminder, scheduled_at: now, next_delivery_at: now)

    allow(DeliverReminderJob).to receive(:perform_later).and_raise("queue unavailable")

    Timecop.freeze(now) do
      expect { described_class.perform_now }.to raise_error("queue unavailable")
    end

    expect(reminder.reload.next_delivery_at).to be_nil
    expect(reminder.reminder_deliveries.count).to eq(2)

    allow(DeliverReminderJob).to receive(:perform_later).and_call_original

    Timecop.freeze(now + 1.minute) do
      expect { described_class.perform_now }
        .to have_enqueued_job(DeliverReminderJob).exactly(:twice)
    end

    expect(reminder.reminder_deliveries.count).to eq(2)
  end

  it "does not amplify already-enqueued pending deliveries during the lease" do
    now = Time.zone.local(2026, 7, 14, 9, 0)
    delivery = create(:reminder_delivery, enqueued_at: now)

    Timecop.freeze(now + 1.minute) do
      expect { described_class.perform_now }.not_to have_enqueued_job(DeliverReminderJob)
    end

    Timecop.freeze(now + described_class::ENQUEUE_LEASE + 1.second) do
      expect { described_class.perform_now }.to have_enqueued_job(DeliverReminderJob).with(delivery)
    end
  end

  it "respects saved notification preferences" do
    now = Time.zone.local(2026, 7, 14, 9, 0)
    reminder = create(:reminder, scheduled_at: now, next_delivery_at: now)
    create(:notification_preference, user: reminder.user, in_app_enabled: true, email_enabled: false)

    Timecop.freeze(now) { described_class.perform_now }

    expect(reminder.reminder_deliveries.pluck(:channel)).to eq([ "in_app" ])
  end

  it "keeps a due occurrence pending when every delivery channel is disabled" do
    now = Time.zone.local(2026, 7, 14, 9, 0)
    reminder = create(:reminder, scheduled_at: now, next_delivery_at: now)
    create(:notification_preference, user: reminder.user, in_app_enabled: false, email_enabled: false)

    Timecop.freeze(now) { described_class.perform_now }

    expect(reminder.reload.next_delivery_at).to eq(now)
    expect(reminder.reminder_deliveries).to be_empty
  end

  it "preloads reminder owners and notification preferences for a due batch" do
    now = Time.zone.local(2026, 7, 14, 9, 0)
    reminder = create(:reminder, scheduled_at: now, next_delivery_at: now)
    create(:notification_preference, user: reminder.user)

    allow(NotificationPreference).to receive(:channels_for).and_wrap_original do |method, user|
      expect(user.association(:notification_preference)).to be_loaded
      method.call(user)
    end

    Timecop.freeze(now) { described_class.perform_now }

    expect(NotificationPreference).to have_received(:channels_for).once
  end

  it "does not claim future or completed reminders" do
    now = Time.zone.local(2026, 7, 14, 9, 0)
    create(:reminder, scheduled_at: now + 1.hour, next_delivery_at: now + 1.hour)
    create(:reminder, status: "completed", completed_at: now - 1.day, next_delivery_at: nil)

    Timecop.freeze(now) do
      expect { described_class.perform_now }.not_to change(ReminderDelivery, :count)
    end
  end
end
