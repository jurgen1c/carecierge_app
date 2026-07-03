# == Schema Information
#
# Table name: relationship_group_memberships
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_group_id   :uuid             not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_5e33b2c4bc                      (relationship_profile_id)
#  index_relationship_group_memberships_on_profile_and_group      (relationship_profile_id,relationship_group_id) UNIQUE
#  index_relationship_group_memberships_on_relationship_group_id  (relationship_group_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_group_id => relationship_groups.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
class RelationshipGroupMembership < ApplicationRecord
  attr_accessor :group_name

  belongs_to :relationship_profile
  belongs_to :relationship_group, autosave: true

  before_validation :assign_relationship_group_from_name, if: -> { group_name.present? }

  validates :relationship_group, presence: true
  validates :relationship_group_id, uniqueness: { scope: :relationship_profile_id }, allow_nil: true
  validate :relationship_group_belongs_to_profile_user

  def name
    relationship_group&.name || group_name
  end

  private

  def assign_relationship_group_from_name
    self.relationship_group = group_for_name(group_name)
  end

  def group_for_name(name)
    normalized_name = name.to_s.strip
    existing_group = relationship_profile.user.relationship_groups.detect { |group| group.name.casecmp?(normalized_name) }

    existing_group || relationship_profile.user.relationship_groups.build(name: normalized_name)
  end

  def relationship_group_belongs_to_profile_user
    return if relationship_group.blank? || relationship_profile.blank?
    return if relationship_group.user == relationship_profile.user

    errors.add(:relationship_group, :invalid)
  end
end
