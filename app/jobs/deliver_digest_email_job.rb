class DeliverDigestEmailJob < ApplicationJob
  class ProcessingLockUnavailable < StandardError; end

  queue_as :background

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(notification)
    event = notification.event
    result = event.record.with_processing_lock do
      delivery = event.record.reload
      next :already_delivered if delivery.email_delivered_at?
      unless final_handoff_allowed?(delivery)
        delivery.update!(status: "cancelled", enqueued_at: nil)
        next :cancelled
      end
      next :skipped unless filter_current_relationships(event, delivery)
      if (deferred_until = delivery.user.notification_preference&.digest_delivery_deferred_until)
        self.class.set(wait_until: deferred_until).perform_later(notification)
        next :deferred
      end

      delivery_method = event.delivery_methods.fetch(:email)
      delivery_method.constant.perform_now(delivery_method.name, notification)
      delivery.update!(email_delivered_at: Time.current)
      :delivered
    end

    raise ProcessingLockUnavailable, "Digest delivery processing lock is busy" if result == false
  end

  private

  def final_handoff_allowed?(delivery)
    preference = delivery.user.notification_preference
    preference&.digest_delivery_allowed? &&
      preference.digest_mode == delivery.mode && preference.digest_channel == delivery.channel &&
      (preference.digest_schedule_changed_at.nil? || delivery.scheduled_for >= preference.digest_schedule_changed_at)
  end

  def filter_current_relationships(event, delivery)
    params = event.params.to_h.deep_stringify_keys
    snapshot = params["digest_snapshot"]
    return true unless snapshot

    items = Array(snapshot["items"])
    profile_ids = items.filter_map { |item| item["relationship_profile_id"] }
    muted_ids = delivery.user.notification_preference.relationship_notification_preferences
      .where(relationship_profile_id: profile_ids)
      .pluck(:relationship_profile_id)
    active_ids = delivery.user.relationship_profiles.active
      .where(id: profile_ids)
      .where.not(id: muted_ids)
      .pluck(:id)
      .map(&:to_s)
    filtered_items = items.select { |item| active_ids.include?(item["relationship_profile_id"].to_s) }

    if filtered_items.empty?
      delivery.update!(status: "skipped", dispatched_at: nil, enqueued_at: nil)
      return false
    end

    if filtered_items.size != items.size
      params["digest_snapshot"]["items"] = filtered_items
      event.update!(params:)
    end
    true
  end
end
