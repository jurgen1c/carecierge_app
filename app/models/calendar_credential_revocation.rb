# == Schema Information
#
# Table name: calendar_credential_revocations
# Database name: primary
#
#  id              :uuid             not null, primary key
#  access_token    :text
#  attempts        :integer          default(0), not null
#  last_error_code :string
#  lock_version    :integer          default(0), not null
#  refresh_token   :text
#  retry_at        :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :uuid             not null
#
# Indexes
#
#  index_calendar_credential_revocations_on_retry_at  (retry_at)
#  index_calendar_credential_revocations_on_user_id   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class CalendarCredentialRevocation < ApplicationRecord
  belongs_to :user

  encrypts :access_token
  encrypts :refresh_token

  validates :retry_at, presence: true
  validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :last_error_code, inclusion: { in: CalendarConnection::ERROR_CODES }, allow_nil: true
  validate :at_least_one_token

  scope :due, -> { where(retry_at: ..Time.current) }

  def credentials
    CalendarConnections::GoogleOauth::Credentials.new(
      access_token:,
      refresh_token:,
      expires_at: nil,
      scopes: []
    )
  end

  def record_failure!(code)
    next_attempt = attempts + 1
    update!(
      attempts: next_attempt,
      last_error_code: code.to_s.in?(CalendarConnection::ERROR_CODES) ? code : "provider_error",
      retry_at: [ 2**next_attempt, 60 ].min.minutes.from_now
    )
  end

  private

  def at_least_one_token
    errors.add(:base, :blank) if access_token.blank? && refresh_token.blank?
  end
end
