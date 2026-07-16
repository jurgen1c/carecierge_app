# == Schema Information
#
# Table name: relationship_notes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  category                :string
#  private                 :boolean          default(FALSE), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_private_777e9fc47b    (relationship_profile_id,private)
#  index_relationship_notes_on_relationship_profile_id  (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
class RelationshipNote < ApplicationRecord
  attr_accessor :privacy_vault_transition

  belongs_to :relationship_profile
  has_rich_text :body
  has_one :privacy_vault_item, as: :protectable, dependent: :destroy

  validate :body_has_visible_text
  validate :vault_protected_content_unchanged, on: :update, unless: :privacy_vault_transition

  def vault_protected?
    privacy_vault_item.present?
  end

  private

  def body_has_visible_text
    errors.add(:body, :blank) if body.to_plain_text.blank?
  end

  def vault_protected_content_unchanged
    return unless PrivacyVaultItem.exists?(protectable_type: self.class.base_class.name, protectable_id: id)
    return if category.blank? && body.to_plain_text == PrivacyVaultItem::REDACTED_TEXT

    errors.add(:base, :vault_protected)
  end
end
