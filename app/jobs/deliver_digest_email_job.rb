class DeliverDigestEmailJob < ApplicationJob
  queue_as :background

  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  def perform(notification)
    event = notification.event
    event.record.with_processing_lock do
      delivery = event.record.reload
      next if delivery.email_delivered_at?

      delivery_method = event.delivery_methods.fetch(:email)
      delivery_method.constant.perform_now(delivery_method.name, notification)
      delivery.update!(email_delivered_at: Time.current)
    end
  end
end
