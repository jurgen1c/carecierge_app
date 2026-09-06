class PrivacyVault::Unlock
  Result = Data.define(:lease, :error)

  def self.call(user:, password:, code: nil)
    user.with_lock do
      outcome = PrivacyVault::Verify.call(user:, password:, code:)
      if outcome.in?(%i[password totp recovery])
        Result.new(lease: PrivacyVault::Lease.issue_for(user), error: nil)
      else
        Result.new(lease: nil, error: outcome)
      end
    end
  end
end
