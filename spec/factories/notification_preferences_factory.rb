# == Schema Information
#
# Table name: notification_preferences
# Database name: primary
#
#  id             :uuid             not null, primary key
#  email_enabled  :boolean          default(TRUE), not null
#  in_app_enabled :boolean          default(TRUE), not null
#  push_enabled   :boolean          default(FALSE), not null
#  sms_enabled    :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :uuid             not null
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
  end
end
