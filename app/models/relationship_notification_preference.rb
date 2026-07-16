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
class RelationshipNotificationPreference < ApplicationRecord
  MODES = %w[muted].freeze

  belongs_to :notification_preference
  belongs_to :relationship_profile

  validates :relationship_profile_id, uniqueness: true
  validates :mode, inclusion: { in: MODES }
  validate :relationship_belongs_to_preference_user

  def muted? = mode == "muted"

  private

  def relationship_belongs_to_preference_user
    return if notification_preference.blank? || relationship_profile.blank?
    return if notification_preference.user_id == relationship_profile.user_id

    errors.add(:relationship_profile, :different_owner)
  end
end
