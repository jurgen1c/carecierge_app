class DispatchSharedRemindersJob < ApplicationJob
  queue_as :background

  def perform
    SharedReminderSubscription.pending_delivery.preload(:user, shared_item: :shared_relationship_space).find_each do |subscription|
      deliver(subscription)
    end
  end

  private

  def deliver(subscription)
    item = subscription.shared_item
    space = item&.shared_relationship_space
    recipient = subscription.user
    return unless space && recipient

    recipient.with_lock("FOR NO KEY UPDATE") do
      space.with_lock do
        subscription.reload
        item.reload
        return unless due?(subscription, item)

        preference = NotificationPreference.find_by(user_id: subscription.user_id)
        return if preference && (!preference.in_app_enabled? || preference.digest_delivery_deferred_until)

        SharedReminderNotifier.with(record: item).deliver(recipient)
        subscription.update!(delivered_for: item.due_at)
      end
    end
  rescue ActiveRecord::RecordNotFound
    # Ending sharing or opting out before delivery cancels the reminder.
  end

  def due?(subscription, item)
    space = item.shared_relationship_space
    subscription.enabled? && space.active? && space.participant?(subscription.user) && item.kind == "reminder" &&
      !item.completed? && item.due_at && item.due_at <= Time.current && subscription.delivered_for != item.due_at
  end
end
