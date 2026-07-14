require "rails_helper"

RSpec.describe DeliverReminderJob, type: :job do
  include ActiveJob::TestHelper

  it "defers its own and Noticed's jobs until database transactions commit" do
    expect(described_class.enqueue_after_transaction_commit).to be(true)
    expect(Noticed.parent_class).to eq("ApplicationJob")
    expect(Noticed::EventJob.enqueue_after_transaction_commit).to be(true)
  end

  it "discards a queued delivery after its reminder is deleted" do
    delivery = create(:reminder_delivery)
    serialized_job = described_class.new(delivery).serialize
    delivery.reminder.destroy!

    expect { described_class.execute(serialized_job) }.not_to have_enqueued_job(described_class)
  end

  it "dispatches an in-app Noticed event and records success" do
    delivery = create(:reminder_delivery, channel: "in_app")

    expect { described_class.perform_now(delivery) }
      .to change(ReminderInAppNotifier, :count).by(1)

    expect(delivery.reload).to have_attributes(status: "dispatched", error_message: nil)
    expect(delivery.dispatched_at).to be_present
    expect(delivery.noticed_event).to be_a(ReminderInAppNotifier)
  end

  it "releases reminder and delivery locks before calling the external email channel" do
    delivery = create(:reminder_delivery, channel: "email")
    reminder = delivery.reminder
    reminder_lock_held = false
    delivery_lock_held = false
    allow(reminder).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      method.call(*args) do
        reminder_lock_held = true
        block.call
      ensure
        reminder_lock_held = false
      end
    end
    allow(delivery).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      method.call(*args) do
        delivery_lock_held = true
        block.call
      ensure
        delivery_lock_held = false
      end
    end
    allow(Noticed::DeliveryMethods::Email).to receive(:perform_now) do
      expect(reminder_lock_held).to be(false)
      expect(delivery_lock_held).to be(false)
    end

    described_class.perform_now(delivery)

    expect(delivery.reload.status).to eq("dispatched")
  end

  it "does not concurrently dispatch a delivery already being processed" do
    delivery = create(:reminder_delivery, status: "dispatching", enqueued_at: Time.current)

    expect(ReminderInAppNotifier).not_to receive(:with)

    described_class.perform_now(delivery)

    expect(delivery.reload.status).to eq("dispatching")
  end

  it "does not enter the delivery flow while another worker owns the processing lock" do
    delivery = create(:reminder_delivery, channel: "email")
    allow(delivery).to receive(:with_processing_lock).and_return(false)

    expect(ReminderEmailNotifier).not_to receive(:with)

    described_class.perform_now(delivery)

    expect(delivery.reload.status).to eq("pending")
  end

  it "does not complete a replacement worker's processing lease" do
    delivery = create(:reminder_delivery, channel: "in_app")
    replacement_token = SecureRandom.uuid
    lock_count = 0
    allow(delivery).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      lock_count += 1
      if lock_count == 3
        delivery.update_columns(
        status: "dispatching",
        enqueued_at: Time.current,
        lease_token: replacement_token
      )
      end
      method.call(*args, &block)
    end

    described_class.perform_now(delivery)

    expect(delivery.reload).to have_attributes(status: "dispatching", lease_token: replacement_token)
  end

  it "reuses a committed Noticed event when an interrupted delivery is recovered" do
    delivery = create(:reminder_delivery, channel: "in_app")
    event = ReminderInAppNotifier.with(record: delivery.reminder)
      .deliver(delivery.reminder.user, enqueue_job: false)
    delivery.update_column(:noticed_event_id, event.id)

    expect { described_class.perform_now(delivery) }
      .not_to change(ReminderInAppNotifier, :count)

    expect(delivery.reload).to have_attributes(status: "dispatched", noticed_event_id: event.id)
  end

  it "cancels an occurrence rescheduled after the processing lease is claimed" do
    delivery = create(:reminder_delivery, channel: "in_app")
    reminder = delivery.reminder
    reminder_lock_count = 0
    allow(reminder).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      reminder_lock_count += 1
      reminder.update!(scheduled_at: delivery.scheduled_for + 1.day) if reminder_lock_count == 2
      method.call(*args, &block)
    end

    expect { described_class.perform_now(delivery) }
      .not_to change(ReminderInAppNotifier, :count)

    expect(delivery.reload.status).to eq("cancelled")
  end

  it "cancels an email rescheduled after event preparation but before channel handoff" do
    delivery = create(:reminder_delivery, channel: "email")
    reminder = delivery.reminder
    allow_any_instance_of(described_class).to receive(:event_for).and_wrap_original do |method, *args|
      event = method.call(*args)
      reminder.update!(scheduled_at: delivery.scheduled_for + 1.day)
      event
    end
    allow(Noticed::DeliveryMethods::Email).to receive(:perform_now)

    described_class.perform_now(delivery)

    expect(Noticed::DeliveryMethods::Email).not_to have_received(:perform_now)
    expect(delivery.reload.status).to eq("cancelled")
  end

  it "does not remove a replacement worker's event when an expired email attempt fails" do
    delivery = create(:reminder_delivery, channel: "email")
    replacement_token = SecureRandom.uuid
    allow(Noticed::DeliveryMethods::Email).to receive(:perform_now) do
      delivery.update_columns(status: "dispatching", enqueued_at: Time.current, lease_token: replacement_token)
      raise StandardError, "expired worker"
    end

    expect { described_class.perform_now(delivery) }
      .to have_enqueued_job(described_class).with(delivery)

    expect(delivery.reload).to have_attributes(status: "dispatching", lease_token: replacement_token)
    expect(delivery.noticed_event).to be_persisted
  end

  it "dispatches an email through Noticed before recording success" do
    delivery = create(:reminder_delivery, channel: "email")
    allow(Noticed::DeliveryMethods::Email).to receive(:perform_now)

    described_class.perform_now(delivery)

    event = ReminderEmailNotifier.find_by!(record: delivery.reminder)
    notification = event.notifications.sole
    expect(Noticed::DeliveryMethods::Email).to have_received(:perform_now).with(:email, notification)
    expect(delivery.reload.status).to eq("dispatched")
  end

  it "executes the Noticed email delivery end to end" do
    delivery = create(:reminder_delivery, channel: "email")

    expect { described_class.perform_now(delivery) }
      .to change(ActionMailer::Base.deliveries, :count).by(1)

    expect(ActionMailer::Base.deliveries.last).to have_attributes(
      to: [ delivery.reminder.user.email ],
      subject: "Reminder: #{delivery.reminder.title}"
    )
  end

  it "records transient failures and automatically schedules a retry" do
    delivery = create(:reminder_delivery, channel: "email")
    allow(Noticed::DeliveryMethods::Email).to receive(:perform_now).and_raise(StandardError, "provider unavailable")

    expect { described_class.perform_now(delivery) }
      .to have_enqueued_job(described_class).with(delivery)
    expect(delivery.reload).to have_attributes(status: "failed", error_message: "provider unavailable")
    expect(ReminderEmailNotifier.where(record: delivery.reminder)).to be_empty
  end

  it "does not dispatch an occurrence twice" do
    delivery = create(:reminder_delivery, status: "dispatched", dispatched_at: 1.minute.ago)

    expect(ReminderInAppNotifier).not_to receive(:with)

    described_class.perform_now(delivery)
  end

  it "cancels a pending occurrence after the reminder is rescheduled" do
    delivery = create(:reminder_delivery)
    delivery.reminder.update!(scheduled_at: delivery.scheduled_for + 1.day)

    expect(ReminderInAppNotifier).not_to receive(:with)

    described_class.perform_now(delivery)

    expect(delivery.reload).to have_attributes(status: "cancelled", dispatched_at: nil, error_message: nil)
  end

  it "cancels a pending occurrence after the reminder is completed" do
    delivery = create(:reminder_delivery)
    delivery.reminder.complete!

    expect(ReminderInAppNotifier).not_to receive(:with)

    described_class.perform_now(delivery)

    expect(delivery.reload).to have_attributes(status: "cancelled", dispatched_at: nil, error_message: nil)
  end
end
