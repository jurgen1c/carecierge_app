class DeliverReminderJob < ApplicationJob
  queue_as :background

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(delivery)
    reminder = delivery.reminder
    reminder.with_lock do
      delivery.with_lock do
        return if delivery.dispatched? || delivery.cancelled?

        reminder.reload
        unless delivery.current_occurrence?(reminder)
          delivery.cancel!
          return
        end

        event = notifier_for(delivery)
          .with(record: reminder)
          .deliver(reminder.user, enqueue_job: false)
        deliver_email(event) if delivery.channel == "email"
        delivery.update!(status: "dispatched", dispatched_at: Time.current, enqueued_at: nil, error_message: nil)
      end
    end
  rescue StandardError => error
    delivery.update!(status: "failed", error_message: error.message)
    raise
  end

  private

  def notifier_for(delivery)
    case delivery.channel
    when "in_app" then ReminderInAppNotifier
    when "email" then ReminderEmailNotifier
    else raise ArgumentError, "Unsupported reminder delivery channel: #{delivery.channel}"
    end
  end

  def deliver_email(event)
    delivery_method = event.delivery_methods.fetch(:email)
    delivery_method.constant.perform_now(delivery_method.name, event.notifications.sole)
  end
end
