# == Schema Information
#
# Table name: relationship_taggings
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  relationship_tag_id     :uuid             not null
#
# Indexes
#
#  index_relationship_taggings_on_profile_and_tag          (relationship_profile_id,relationship_tag_id) UNIQUE
#  index_relationship_taggings_on_relationship_profile_id  (relationship_profile_id)
#  index_relationship_taggings_on_relationship_tag_id      (relationship_tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (relationship_tag_id => relationship_tags.id) ON DELETE => cascade
#
class RelationshipTagging < ApplicationRecord
  attr_accessor :tag_name

  belongs_to :relationship_profile
  belongs_to :relationship_tag, autosave: true

  before_validation :assign_relationship_tag_from_name, if: -> { tag_name.present? }

  validates :relationship_tag, presence: true
  validates :relationship_tag_id, uniqueness: { scope: :relationship_profile_id }, allow_nil: true
  validate :relationship_tag_belongs_to_profile_user

  def name
    relationship_tag&.name || tag_name
  end

  private

  def assign_relationship_tag_from_name
    self.relationship_tag = tag_for_name(tag_name)
  end

  def tag_for_name(name)
    normalized_name = name.to_s.strip

    relationship_profile
      .user
      .relationship_tags
      .where("LOWER(name) = ?", normalized_name.downcase)
      .first_or_initialize(name: normalized_name)
  end

  def relationship_tag_belongs_to_profile_user
    return if relationship_tag.blank? || relationship_profile.blank?
    return if relationship_tag.user == relationship_profile.user

    errors.add(:relationship_tag, :invalid)
  end
end
