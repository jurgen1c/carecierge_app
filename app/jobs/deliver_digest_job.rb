class DeliverDigestJob < ApplicationJob
  queue_as :background

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(delivery)
    delivery.with_processing_lock do
      return unless start_delivery(delivery)

      preference = delivery.user.notification_preference
      occurrence = delivery.scheduled_for.in_time_zone(preference.time_zone)
      digest = Digests::Compose.call(
        user: delivery.user,
        as_of: preference.digest_effective_delivery_at(occurrence),
        mode: delivery.mode
      )
      return finish(delivery, "skipped") if digest.empty?
      return unless handoff_allowed?(delivery)

      event = event_for(delivery, digest:)
      if delivery.channel == "email" && delivery.handed_off_at?
        enqueue_email(event)
        return finish(delivery, "dispatched")
      end

      deliver(delivery, event)
      finish(delivery, "dispatched")
    end
  rescue StandardError => error
    delivery.update!(status: "failed", enqueued_at: nil, error_message: error.message) if delivery&.persisted?
    raise
  end

  private

  def start_delivery(delivery)
    delivery.with_lock do
      return false if delivery.dispatched? || delivery.skipped? || delivery.cancelled? || delivery.dispatching?

      preference = delivery.user.notification_preference
      unless preference&.digest_delivery_allowed? &&
          preference.digest_mode == delivery.mode && preference.digest_channel == delivery.channel &&
          current_schedule?(delivery, preference)
        delivery.update!(status: "cancelled", enqueued_at: nil)
        return false
      end

      delivery.update!(status: "dispatching", enqueued_at: Time.current, error_message: nil)
      true
    end
  end

  def current_schedule?(delivery, preference)
    preference.digest_schedule_changed_at.nil? || delivery.scheduled_for >= preference.digest_schedule_changed_at
  end

  def handoff_allowed?(delivery)
    delivery.with_lock do
      preference = NotificationPreference.find_by(user_id: delivery.user_id)
      allowed = preference&.digest_delivery_allowed? &&
        preference.digest_mode == delivery.mode && preference.digest_channel == delivery.channel &&
        current_schedule?(delivery, preference)
      delivery.update!(status: "cancelled", enqueued_at: nil) unless allowed
      allowed
    end
  end

  def event_for(delivery, digest:)
    notifier = delivery.channel == "email" ? DigestEmailNotifier : DigestInAppNotifier
    params = { record: delivery, mode: delivery.mode }
    params[:digest_snapshot] = Digests::Snapshot.dump(digest)
    notifier.find_by(record: delivery) || notifier.with(**params).deliver(delivery.user, enqueue_job: false)
  end

  def deliver(delivery, event)
    case delivery.channel
    when "email"
      delivery.update!(handed_off_at: Time.current)
      enqueue_email(event)
    when "in_app"
      event
    else
      raise ArgumentError, "Unsupported digest delivery channel: #{delivery.channel}"
    end
  end

  def enqueue_email(event)
    DeliverDigestEmailJob.perform_later(event.notifications.sole)
  end

  def finish(delivery, status)
    delivery.update!(
      status:,
      dispatched_at: status == "dispatched" ? Time.current : nil,
      enqueued_at: nil,
      error_message: nil
    )
  end
end
