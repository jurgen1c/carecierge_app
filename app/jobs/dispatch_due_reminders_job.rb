class DispatchDueRemindersJob < ApplicationJob
  ENQUEUE_LEASE = 15.minutes

  queue_as :background

  def perform
    recover_pending_deliveries

    Reminder.due.includes(:relationship_profile, user: { notification_preference: :relationship_notification_preferences }).find_each do |reminder|
      user = reminder.user
      preference = user.notification_preference || NotificationPreference.new(user:)
      relationship_profile = reminder.relationship_profile
      claim_deliveries(reminder, user, preference, relationship_profile:)
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

  def claim_deliveries(reminder, user, preference, relationship_profile:)
    deliveries = reminder.with_lock do
      due_at = reminder.next_delivery_at
      next [] if due_at.blank? || due_at > Time.current || !reminder.active?

      if (deferred_until = preference.delivery_deferred_until(reminder))
        reminder.update_column(:next_delivery_at, deferred_until)
        next []
      end

      deliveries = NotificationPreference.channels_for(user, reminder:, relationship_profile:).map do |channel|
        delivery = reminder.reminder_deliveries.find_or_initialize_by(channel:, scheduled_for: reminder.effective_delivery_at)
        delivery.save! if delivery.new_record?
        delivery.revive!
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
