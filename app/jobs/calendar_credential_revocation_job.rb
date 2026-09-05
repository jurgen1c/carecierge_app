class CalendarCredentialRevocationJob < ApplicationJob
  queue_as :background

  discard_on ActiveJob::DeserializationError

  def perform(revocation)
    retry_at = nil
    revocation.with_lock do
      next if revocation.retry_at.future?

      CalendarConnections::GoogleOauth.revoke(credentials: revocation.credentials)
      revocation.destroy!
    rescue CalendarConnections::ConnectionError => error
      revocation.record_failure!(error.code)
      retry_at = revocation.retry_at
    end
    self.class.set(wait_until: retry_at).perform_later(revocation) if retry_at
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
