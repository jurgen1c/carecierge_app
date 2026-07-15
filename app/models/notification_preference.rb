# == Schema Information
#
# Table name: notification_preferences
# Database name: primary
#
#  id                           :uuid             not null, primary key
#  digest_mode                  :string           default("off"), not null
#  digest_time                  :time             default(2000-01-01 09:00:00.000000000 UTC +00:00), not null
#  digest_weekday               :integer          default(1), not null
#  email_enabled                :boolean          default(TRUE), not null
#  high_priority_alerts_enabled :boolean          default(TRUE), not null
#  in_app_enabled               :boolean          default(TRUE), not null
#  push_enabled                 :boolean          default(FALSE), not null
#  quiet_hours_enabled          :boolean          default(FALSE), not null
#  quiet_hours_end              :time             default(2000-01-01 07:00:00.000000000 UTC +00:00), not null
#  quiet_hours_start            :time             default(2000-01-01 22:00:00.000000000 UTC +00:00), not null
#  reminder_frequency           :string           default("none"), not null
#  reminder_lead_minutes        :integer          default(1440), not null
#  sms_enabled                  :boolean          default(FALSE), not null
#  time_zone                    :string           default("UTC"), not null
#  time_zone_configured         :boolean          default(FALSE), not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  user_id                      :uuid             not null
#
# Indexes
#
#  index_notification_preferences_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class NotificationPreference < ApplicationRecord
  DeliveryDecision = Data.define(:status, :deferred_until) do
    def allow? = status == :allow
  end

  REMINDER_FREQUENCIES = Reminder::RECURRENCES
  REMINDER_LEAD_MINUTES = [ 0, 60, 1_440, 10_080, 20_160, 43_200 ].freeze
  DIGEST_MODES = %w[off daily weekly].freeze

  CHANNEL_ATTRIBUTES = {
    "in_app" => :in_app_enabled,
    "email" => :email_enabled
  }.freeze

  belongs_to :user
  has_many :relationship_notification_preferences, dependent: :destroy

  validates :user_id, uniqueness: true
  validates :reminder_frequency, inclusion: { in: REMINDER_FREQUENCIES }
  validates :reminder_lead_minutes, inclusion: { in: REMINDER_LEAD_MINUTES }
  validates :digest_mode, inclusion: { in: DIGEST_MODES }
  validates :digest_weekday, inclusion: { in: 0..6 }
  validates :quiet_hours_start, :quiet_hours_end, :digest_time, presence: true
  validate :recognized_time_zone
  validate :quiet_hours_have_distinct_boundaries

  def self.channels_for(user, reminder: nil, relationship_profile: reminder&.relationship_profile)
    preference = user.notification_preference || new(user:)

    CHANNEL_ATTRIBUTES.keys.select { |channel| preference.delivery_allowed?(channel, reminder:, relationship_profile:) }
  end

  def self.current_delivery_decision(user, reminder:, channel:, at: Time.current)
    preference = find_by(user_id: user.id) || new(user:)
    return DeliveryDecision.new(status: :cancel, deferred_until: nil) unless preference.delivery_allowed?(channel, reminder:)

    deferred_until = preference.delivery_deferred_until(reminder, at:)
    return DeliveryDecision.new(status: :defer, deferred_until:) if deferred_until

    DeliveryDecision.new(status: :allow, deferred_until: nil)
  end

  def self.reminder_frequency_options
    REMINDER_FREQUENCIES.map { |value| [ I18n.t("notification_preferences.reminder_frequencies.#{value}"), value ] }
  end

  def self.reminder_lead_options
    REMINDER_LEAD_MINUTES.map { |value| [ I18n.t("notification_preferences.reminder_leads.#{value}"), value ] }
  end

  def self.digest_mode_options
    DIGEST_MODES.map { |value| [ I18n.t("notification_preferences.digest_modes.#{value}"), value ] }
  end

  def self.digest_weekday_options
    (0..6).map { |index| [ I18n.t("notification_preferences.weekdays.#{index}"), index ] }
  end

  def delivery_deferred_until(reminder, at: Time.current)
    return unless quiet_hours_enabled?
    return if reminder.priority == "high" && high_priority_alerts_enabled?

    local_time = at.in_time_zone(time_zone_object)
    return unless quiet_hours_include?(local_time)

    quiet_hours_end_after(local_time)
  end

  def delivery_allowed?(channel, reminder:, relationship_profile: reminder&.relationship_profile)
    attribute = CHANNEL_ATTRIBUTES[channel]
    attribute.present? && public_send(attribute) && !muted_for_reminder?(relationship_profile)
  end

  def muted_for?(relationship_profile_id)
    overrides = relationship_notification_preferences
    if overrides.loaded?
      overrides.any? { |override| override.relationship_profile_id == relationship_profile_id && override.muted? }
    else
      overrides.exists?(relationship_profile_id:, mode: "muted")
    end
  end

  private

  def muted_for_reminder?(relationship_profile)
    relationship_profile.present? && !relationship_profile.archived? && muted_for?(relationship_profile.id)
  end

  def recognized_time_zone
    errors.add(:time_zone, :invalid) if time_zone.blank? || ActiveSupport::TimeZone[time_zone].blank?
  end

  def quiet_hours_have_distinct_boundaries
    return if quiet_hours_start.blank? || quiet_hours_end.blank?
    return unless seconds_since_midnight(quiet_hours_start) == seconds_since_midnight(quiet_hours_end)

    errors.add(:quiet_hours_end, :same_as_start)
  end

  def quiet_hours_include?(local_time)
    current = seconds_since_midnight(local_time)
    starts_at = seconds_since_midnight(quiet_hours_start)
    ends_at = seconds_since_midnight(quiet_hours_end)

    if starts_at < ends_at
      current >= starts_at && current < ends_at
    else
      current >= starts_at || current < ends_at
    end
  end

  def quiet_hours_end_after(local_time)
    ends_at = seconds_since_midnight(quiet_hours_end)
    current = seconds_since_midnight(local_time)
    date = local_time.to_date
    date += 1.day if seconds_since_midnight(quiet_hours_start) > ends_at && current >= seconds_since_midnight(quiet_hours_start)
    hours, remainder = ends_at.divmod(1.hour)
    minutes, seconds = remainder.divmod(1.minute)

    next_local_boundary(date, hours, minutes, seconds, after: local_time)
  end

  def next_local_boundary(date, hours, minutes, seconds, after:)
    zone = time_zone_object
    wall_time = Time.utc(date.year, date.month, date.day, hours, minutes, seconds)
    periods = zone.tzinfo.periods_for_local(wall_time)
    return zone.local(date.year, date.month, date.day, hours, minutes, seconds) if periods.empty?

    candidates = periods.map do |period|
      (wall_time - period.utc_total_offset).in_time_zone(zone)
    end
    upcoming = candidates.select { |candidate| candidate > after }.min
    return upcoming if upcoming

    zone.local(date.year, date.month, date.day, hours, minutes, seconds)
  end

  def seconds_since_midnight(value)
    (value.hour * 3_600) + (value.min * 60) + value.sec
  end

  def time_zone_object
    ActiveSupport::TimeZone[time_zone] || Time.zone
  end
end
