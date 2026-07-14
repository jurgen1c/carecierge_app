class DispatchDueRemindersJob < ApplicationJob
  ENQUEUE_LEASE = 15.minutes

  queue_as :background

  def perform
    recover_pending_deliveries

    Reminder.due.includes(user: :notification_preference).find_each do |reminder|
      user = reminder.user
      user.notification_preference
      claim_deliveries(reminder, user)
    end
  end

  private

  def recover_pending_deliveries
    recover_before = ENQUEUE_LEASE.ago
    ReminderDelivery.recoverable(before: recover_before).includes(:reminder).find_each do |delivery|
      should_enqueue = delivery.with_processing_lock { prepare_delivery(delivery, recover_before:) }
      enqueue_claimed_delivery(delivery) if should_enqueue
    end
  end

  def claim_deliveries(reminder, user)
    deliveries = reminder.with_lock do
      scheduled_for = reminder.next_delivery_at
      next [] if scheduled_for.blank? || scheduled_for > Time.current || !reminder.active?

      deliveries = NotificationPreference.channels_for(user).map do |channel|
        ReminderDelivery.create_or_find_by!(reminder:, channel:, scheduled_for:)
      end
      reminder.update_column(:next_delivery_at, nil) if deliveries.any?
      deliveries
    end

    deliveries.each { |delivery| enqueue_delivery(delivery) }
  end

  def enqueue_delivery(delivery)
    enqueue_claimed_delivery(delivery) if prepare_delivery(delivery)
  end

  def prepare_delivery(delivery, recover_before: nil)
    delivery.with_lock do
      next false if recover_before && !delivery.recoverable?(before: recover_before)

      delivery.update!(status: "pending", enqueued_at: nil, lease_token: nil) if delivery.dispatching?
      next false unless delivery.pending?

      if delivery.current_occurrence?
        delivery.update!(enqueued_at: Time.current)
        true
      else
        delivery.cancel!
        false
      end
    end
  end

  def enqueue_claimed_delivery(delivery)
    DeliverReminderJob.perform_later(delivery)
  rescue StandardError
    delivery.update_column(:enqueued_at, nil) if delivery.persisted? && delivery.pending?
    raise
  end
end
