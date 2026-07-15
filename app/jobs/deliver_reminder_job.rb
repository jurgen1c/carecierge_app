class DeliverReminderJob < ApplicationJob
  queue_as :background

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(delivery)
    delivery.with_processing_lock { process(delivery) }
  end

  private

  def process(delivery)
    reminder = delivery.reminder
    lease_token = start_delivery(delivery, reminder)
    return unless lease_token

    event = event_for(delivery, reminder, lease_token)
    return unless event

    if delivery.channel == "email"
      return unless prepare_email_handoff(delivery, reminder, event, lease_token)

      deliver_email(event)
    end
    finish_delivery(delivery, lease_token)
  rescue StandardError => error
    fail_delivery(delivery, event, lease_token, error)
    raise
  end

  def start_delivery(delivery, reminder)
    reminder.with_lock do
      delivery.with_lock do
        return false if delivery.dispatched? || delivery.cancelled? || delivery.dispatching?

        reminder.reload
        unless delivery.current_occurrence?(reminder)
          delivery.cancel!
          return false
        end
        return false unless preferences_allow_handoff?(delivery, reminder)

        lease_token = SecureRandom.uuid
        delivery.update!(status: "dispatching", enqueued_at: Time.current, lease_token:, error_message: nil)
        lease_token
      end
    end
  end

  def finish_delivery(delivery, lease_token)
    delivery.with_lock do
      return unless owns_lease?(delivery, lease_token)

      delivery.update!(status: "dispatched", dispatched_at: Time.current, enqueued_at: nil, lease_token: nil, error_message: nil)
    end
  end

  def fail_delivery(delivery, event, lease_token, error)
    delivery.with_lock do
      return unless owns_lease?(delivery, lease_token)

      event.destroy! if event && delivery.noticed_event_id == event.id
      delivery.update!(status: "failed", enqueued_at: nil, lease_token: nil, error_message: error.message)
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def event_for(delivery, reminder, lease_token)
    reminder.with_lock do
      delivery.with_lock do
        reminder.reload
        unless owns_lease?(delivery, lease_token) && delivery.current_occurrence?(reminder)
          delivery.cancel! if owns_lease?(delivery, lease_token)
          return
        end
        return unless preferences_allow_handoff?(delivery, reminder)
        return delivery.noticed_event if delivery.noticed_event

        event = notifier_for(delivery)
          .with(record: reminder)
          .deliver(reminder.user, enqueue_job: false)
        delivery.update!(noticed_event_id: event.id)
        event
      end
    end
  end

  def owns_lease?(delivery, lease_token)
    delivery.dispatching? && delivery.lease_token == lease_token
  end

  def prepare_email_handoff(delivery, reminder, event, lease_token)
    reminder.with_lock do
      delivery.with_lock do
        reminder.reload
        unless owns_lease?(delivery, lease_token) && delivery.current_occurrence?(reminder)
          delivery.cancel! if owns_lease?(delivery, lease_token)
          return false
        end
        return false unless preferences_allow_handoff?(delivery, reminder)

        delivery.update!(enqueued_at: Time.current)
        true
      end
    end
  end

  def notifier_for(delivery)
    case delivery.channel
    when "in_app" then ReminderInAppNotifier
    when "email" then ReminderEmailNotifier
    else raise ArgumentError, "Unsupported reminder delivery channel: #{delivery.channel}"
    end
  end

  def current_preferences_allow?(delivery, reminder)
    current_preference_decision(delivery, reminder).allow?
  end

  def preferences_allow_handoff?(delivery, reminder)
    decision = current_preference_decision(delivery, reminder)
    return true if decision.allow?

    cancel_for_preferences!(delivery, reminder, restore_at: decision.deferred_until)
    false
  end

  def current_preference_decision(delivery, reminder)
    NotificationPreference.current_delivery_decision(
      reminder.user,
      reminder:,
      channel: delivery.channel
    )
  end

  def cancel_for_preferences!(delivery, reminder, restore_at: nil)
    occurrence = delivery.scheduled_for
    delivery.cancel!
    viable_delivery_exists = reminder.reminder_deliveries
      .where(scheduled_for: occurrence)
      .where.not(id: delivery.id)
      .where.not(status: "cancelled")
      .any? { |other_delivery| other_delivery.dispatched? || current_preferences_allow?(other_delivery, reminder) }

    if restore_at
      reminder.update_column(:next_delivery_at, restore_at)
    elsif !viable_delivery_exists
      reminder.update_column(:next_delivery_at, occurrence)
    end
  end

  def deliver_email(event)
    delivery_method = event.delivery_methods.fetch(:email)
    delivery_method.constant.perform_now(delivery_method.name, event.notifications.sole)
  end
end
