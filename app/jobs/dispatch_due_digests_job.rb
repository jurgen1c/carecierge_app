class DispatchDueDigestsJob < ApplicationJob
  LOOKBACK = 8.days
  ENQUEUE_LEASE = 15.minutes

  queue_as :background

  def perform
    recover_deliveries

    NotificationPreference.where.not(digest_mode: "off").includes(:user).find_each do |preference|
      delivery = preference.with_lock do
        occurrence = preference.due_digest_occurrence(lookback: LOOKBACK)
        next unless occurrence

        DigestDelivery.find_or_create_by!(user: preference.user, scheduled_for: occurrence) do |claim|
          claim.mode = preference.digest_mode
          claim.channel = preference.digest_channel
        end
      end
      next unless delivery

      enqueue(delivery, wait_until: preference.digest_delivery_deferred_until)
    end
  end

  private

  def recover_deliveries
    recover_before = ENQUEUE_LEASE.ago
    DigestDelivery.recoverable(before: recover_before).find_each do |delivery|
      wait_until = delivery.user.notification_preference&.digest_delivery_deferred_until
      enqueue(delivery, recover_before:, wait_until:)
    end
  end

  def enqueue(delivery, recover_before: nil, wait_until: nil)
    claimed = delivery.with_processing_lock { prepare(delivery, recover_before:, wait_until:) }
    return unless claimed

    if wait_until
      DeliverDigestJob.set(wait_until:).perform_later(delivery)
    else
      DeliverDigestJob.perform_later(delivery)
    end
  rescue StandardError
    delivery.update_column(:enqueued_at, nil) if delivery.persisted? && delivery.pending?
    raise
  end

  def prepare(delivery, recover_before: nil, wait_until: nil)
    delivery.with_lock do
      next false if recover_before && !delivery.recoverable?(before: recover_before)
      next false if delivery.pending? && delivery.enqueued_at.present? && recover_before.nil?
      next false unless delivery.pending? || delivery.dispatching?

      delivery.update!(status: "pending", enqueued_at: wait_until || Time.current, error_message: nil)
      true
    end
  end
end
