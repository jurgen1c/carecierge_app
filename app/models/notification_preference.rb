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
class NotificationPreference < ApplicationRecord
  CHANNEL_ATTRIBUTES = {
    "in_app" => :in_app_enabled,
    "email" => :email_enabled
  }.freeze

  belongs_to :user

  validates :user_id, uniqueness: true

  def self.channels_for(user)
    preference = user.notification_preference || new(user:)

    CHANNEL_ATTRIBUTES.filter_map { |channel, attribute| channel if preference.public_send(attribute) }
  end
end
