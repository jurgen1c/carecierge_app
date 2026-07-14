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
    ReminderDelivery.recoverable(before: ENQUEUE_LEASE.ago).includes(:reminder).find_each { |delivery| enqueue_delivery(delivery) }
  end

  def claim_deliveries(reminder, user)
    deliveries = reminder.with_lock do
      scheduled_for = reminder.next_delivery_at
      next [] if scheduled_for.blank? || scheduled_for > Time.current || !reminder.active?

      deliveries = NotificationPreference.channels_for(user).map do |channel|
        ReminderDelivery.create_or_find_by!(reminder:, channel:, scheduled_for:)
      end
      reminder.update_column(:next_delivery_at, nil)
      deliveries
    end

    deliveries.each { |delivery| enqueue_delivery(delivery) }
  end

  def enqueue_delivery(delivery)
    should_enqueue = delivery.with_lock do
      next false unless delivery.pending?

      if delivery.current_occurrence?
        delivery.update!(enqueued_at: Time.current)
        true
      else
        delivery.cancel!
        false
      end
    end
    return unless should_enqueue

    DeliverReminderJob.perform_later(delivery)
  rescue StandardError
    delivery.update_column(:enqueued_at, nil) if delivery.persisted? && delivery.pending?
    raise
  end
end
