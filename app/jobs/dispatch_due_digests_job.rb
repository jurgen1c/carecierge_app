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

      enqueue(delivery)
    end
  end

  private

  def recover_deliveries
    recover_before = ENQUEUE_LEASE.ago
    DigestDelivery.recoverable(before: recover_before).find_each do |delivery|
      claimed = delivery.with_processing_lock { prepare(delivery, recover_before:) }
      DeliverDigestJob.perform_later(delivery) if claimed
    end
  end

  def enqueue(delivery)
    claimed = delivery.with_processing_lock { prepare(delivery) }
    return unless claimed

    DeliverDigestJob.perform_later(delivery)
  rescue StandardError
    delivery.update_column(:enqueued_at, nil) if delivery.persisted? && delivery.pending?
    raise
  end

  def prepare(delivery, recover_before: nil)
    delivery.with_lock do
      next false if recover_before && !delivery.recoverable?(before: recover_before)
      next false if delivery.pending? && delivery.enqueued_at.present?
      next false unless delivery.pending? || delivery.dispatching?

      delivery.update!(status: "pending", enqueued_at: Time.current, error_message: nil)
      true
    end
  end
end
