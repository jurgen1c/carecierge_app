# == Schema Information
#
# Table name: automation_permissions
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  capability              :string           not null
#  mode                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_automation_permissions_account_defaults              (user_id,capability) UNIQUE WHERE (relationship_profile_id IS NULL)
#  idx_automation_permissions_relationship_overrides        (user_id,relationship_profile_id,capability) UNIQUE WHERE (relationship_profile_id IS NOT NULL)
#  index_automation_permissions_on_relationship_profile_id  (relationship_profile_id)
#  index_automation_permissions_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#  fk_rails_...  (user_id => users.id)
#
class AutomationPermission < ApplicationRecord
  belongs_to :user
  belongs_to :relationship_profile, optional: true

  validates :capability,
            presence: true,
            inclusion: { in: AutomationCapability.all.map(&:key) },
            uniqueness: { scope: %i[user_id relationship_profile_id] }
  validates :mode, presence: true, inclusion: { in: AutomationCapability::MODES }
  validate :mode_allowed_for_capability
  validate :relationship_owned_by_user

  scope :account_defaults, -> { where(relationship_profile_id: nil) }
  scope :relationship_overrides, -> { where.not(relationship_profile_id: nil) }

  def self.decision_for(user:, capability:, relationship_profile: nil)
    definition = AutomationCapability.fetch(capability)
    mode = effective_mode_for(user:, definition:, relationship_profile:)

    AutomationPermissionDecision.new(capability: definition, mode:)
  end

  def override?
    relationship_profile_id.present?
  end

  def account_default?
    !override?
  end

  def capability_definition
    AutomationCapability.fetch(capability)
  end

  class << self
    private

    def effective_mode_for(user:, definition:, relationship_profile:)
      if relationship_profile
        current_relationship = user.relationship_profiles.kept.find_by(id: relationship_profile.id)
        unless current_relationship
          return "disabled" if user.relationship_profiles.exists?(id: relationship_profile.id)

          raise ActiveRecord::RecordNotFound
        end

        override = find_by(user:, relationship_profile: current_relationship, capability: definition.key)
        return override.mode if override
      end

      find_by(user:, relationship_profile: nil, capability: definition.key)&.mode || "disabled"
    end
  end

  private

  def mode_allowed_for_capability
    return if capability.blank? || mode.blank?

    definition = AutomationCapability.fetch(capability)
    errors.add(:mode, :inclusion) unless mode.in?(definition.allowed_modes)
  rescue KeyError
    nil
  end

  def relationship_owned_by_user
    return if relationship_profile_id.blank? || user_id.blank?
    return if RelationshipProfile.where(id: relationship_profile_id, user_id:).exists?

    errors.add(:relationship_profile, :invalid)
  end
end
