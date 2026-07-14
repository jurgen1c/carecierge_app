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
    event = instance_double(ReminderInAppNotifier, deliver: true)
    allow(ReminderInAppNotifier).to receive(:with).with(record: delivery.reminder).and_return(event)

    described_class.perform_now(delivery)

    expect(event).to have_received(:deliver).with(delivery.reminder.user, enqueue_job: false)
    expect(delivery.reload).to have_attributes(status: "dispatched", error_message: nil)
    expect(delivery.dispatched_at).to be_present
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
