# == Schema Information
#
# Table name: relationship_notification_preferences
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  mode                       :string           default("muted"), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  notification_preference_id :uuid             not null
#  relationship_profile_id    :uuid             not null
#
# Indexes
#
#  idx_on_notification_preference_id_f719334035  (notification_preference_id)
#  idx_on_relationship_profile_id_ed7238d212     (relationship_profile_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (notification_preference_id => notification_preferences.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :relationship_notification_preference do
    notification_preference
    relationship_profile { association :relationship_profile, user: notification_preference.user }
    mode { "muted" }
  end
end
