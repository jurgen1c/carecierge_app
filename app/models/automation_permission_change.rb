# == Schema Information
#
# Table name: automation_permission_changes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  action                  :string           not null
#  capability              :string           not null
#  new_mode                :string
#  previous_mode           :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  actor_id                :uuid             not null
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_automation_permission_changes_relationship_time             (relationship_profile_id,created_at)
#  index_automation_permission_changes_on_actor_id                 (actor_id)
#  index_automation_permission_changes_on_relationship_profile_id  (relationship_profile_id)
#  index_automation_permission_changes_on_user_id                  (user_id)
#  index_automation_permission_changes_on_user_id_and_created_at   (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class AutomationPermissionChange < ApplicationRecord
  ACTIONS = %w[created updated removed].freeze

  belongs_to :user
  belongs_to :actor, class_name: "User"
  belongs_to :relationship_profile, optional: true

  validates :capability, presence: true, inclusion: { in: AutomationCapability.all.map(&:key) }
  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :previous_mode, inclusion: { in: AutomationCapability::MODES }, allow_nil: true
  validates :new_mode, inclusion: { in: AutomationCapability::MODES }, allow_nil: true
  validate :action_matches_new_mode
  validate :actor_must_be_owner

  def readonly?
    persisted?
  end

  private

  def action_matches_new_mode
    return if action == "removed" && new_mode.nil?
    return if action.in?(%w[created updated]) && new_mode.present?

    errors.add(:new_mode, :invalid)
  end

  def actor_must_be_owner
    return if actor.blank? || user.blank? || actor == user

    errors.add(:actor, :invalid)
  end
end
