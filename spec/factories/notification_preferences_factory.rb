# == Schema Information
#
# Table name: notification_preferences
# Database name: primary
#
#  id                           :uuid             not null, primary key
#  digest_channel               :string           default("email"), not null
#  digest_mode                  :string           default("off"), not null
#  digest_schedule_changed_at   :datetime
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
FactoryBot.define do
  factory :notification_preference do
    user
    in_app_enabled { true }
    email_enabled { true }
    push_enabled { false }
    sms_enabled { false }
    time_zone_configured { true }
  end
end
