# == Schema Information
#
# Table name: calendar_connections
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  access_token          :text             not null
#  granted_scopes        :string           default([]), not null, is an Array
#  last_error_at         :datetime
#  last_error_code       :string
#  last_sync_started_at  :datetime
#  last_synced_at        :datetime
#  locale                :string           default("en"), not null
#  lock_version          :integer          default(0), not null
#  pending_audit_count   :integer          default(0), not null
#  provider              :string           default("google_calendar"), not null
#  refresh_token         :text             not null
#  resync_requested      :boolean          default(FALSE), not null
#  sync_lease_expires_at :datetime
#  sync_lease_token      :uuid
#  sync_status           :string           default("connected"), not null
#  sync_types            :string           default([]), not null, is an Array
#  token_expires_at      :datetime         not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  user_id               :uuid             not null
#
# Indexes
#
#  index_calendar_connections_on_sync_lease  (sync_status,sync_lease_expires_at)
#  index_calendar_connections_on_user_id     (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class CalendarConnection < ApplicationRecord
  GOOGLE_SCOPE = "https://www.googleapis.com/auth/calendar.events.owned"
  PROVIDERS = %w[google_calendar].freeze
  SYNC_TYPES = %w[important_dates reminders event_plans bookings commitments].freeze
  SYNC_STATUSES = %w[connected syncing failed action_required].freeze
  RETRYABLE_ERROR_CODES = %w[provider_unavailable rate_limited].freeze
  ERROR_CODES = %w[
    authorization_required
    calendar_authorization_incomplete
    calendar_permission_required
    invalid_grant
    invalid_provider_response
    provider_error
    provider_rejected
    provider_unavailable
    rate_limited
    revocation_failed
  ].freeze

  belongs_to :user
  has_many :calendar_event_syncs, dependent: :destroy
  has_many :targeted_audit_events, as: :target, class_name: "AuditEvent", dependent: :nullify

  encrypts :access_token
  encrypts :refresh_token

  validates :user_id, uniqueness: true
  validates :provider, inclusion: { in: PROVIDERS }
  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }
  validates :sync_status, inclusion: { in: SYNC_STATUSES }
  validates :last_error_code, inclusion: { in: ERROR_CODES }, allow_nil: true
  validates :pending_audit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :access_token, :refresh_token, :token_expires_at, presence: true
  validate :supported_unique_sync_types
  validate :required_scope_granted
  validate :complete_sync_lease

  scope :eligible_for_sync, -> do
    connected = where(sync_status: "connected")
    retryable = where(sync_status: "failed", last_error_code: RETRYABLE_ERROR_CODES)
    expired = where(sync_status: "syncing", sync_lease_expires_at: ..Time.current)
    connected.or(retryable).or(expired)
  end

  def syncs?(sync_type) = sync_types.include?(sync_type.to_s)
  def actively_syncing? = sync_status == "syncing" && sync_lease_expires_at&.future?
  def syncable?(owner_requested: false)
    sync_status == "connected" || retryable_failure? || expired_sync? || owner_recoverable_failure?(owner_requested:)
  end

  private

  def supported_unique_sync_types
    values = Array(sync_types)
    errors.add(:sync_types, :invalid) if values.uniq.length != values.length || (values - SYNC_TYPES).any?
  end

  def required_scope_granted
    errors.add(:granted_scopes, :missing_calendar_scope) unless Array(granted_scopes).include?(GOOGLE_SCOPE)
  end

  def retryable_failure? = sync_status == "failed" && last_error_code.in?(RETRYABLE_ERROR_CODES)
  def owner_recoverable_failure?(owner_requested:) = owner_requested && sync_status == "failed" && last_error_code != "revocation_failed"
  def expired_sync? = sync_status == "syncing" && sync_lease_expires_at&.past?

  def complete_sync_lease
    lease_complete = sync_lease_token.present? && sync_lease_expires_at.present?
    errors.add(:sync_status, :invalid) unless sync_status == "syncing" ? lease_complete : !lease_complete
  end
end
