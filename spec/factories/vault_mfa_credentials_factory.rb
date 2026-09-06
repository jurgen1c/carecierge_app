FactoryBot.define do
  factory :vault_mfa_credential do
    user
    totp_secret { ROTP::Base32.random }
    enabled_at { Time.current }
  end
end
