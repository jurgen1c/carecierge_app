module CalendarConnections
  class StoreCredentialRevocation
    def self.call(user:, credentials:, error_code:)
      revocation = user.with_lock("FOR NO KEY UPDATE") do
        user.calendar_credential_revocations.create!(
          access_token: credentials.access_token,
          refresh_token: credentials.refresh_token,
          attempts: 1,
          last_error_code: error_code,
          retry_at: 2.minutes.from_now
        )
      end
      CalendarCredentialRevocationJob.set(wait_until: revocation.retry_at).perform_later(revocation)
      revocation
    end
  end
end
