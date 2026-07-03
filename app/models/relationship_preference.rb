# == Schema Information
#
# Table name: relationship_preferences
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  key                     :string           not null
#  value                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_relationship_preferences_on_profile_and_lower_key      (relationship_profile_id, lower((key)::text)) UNIQUE
#  index_relationship_preferences_on_relationship_profile_id  (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
class RelationshipPreference < ApplicationRecord
  belongs_to :relationship_profile

  before_validation :normalize_key

  validates :key, presence: true, uniqueness: { scope: :relationship_profile_id, case_sensitive: false }
  validates :value, presence: true

  private

  def normalize_key
    self.key = key.to_s.strip
  end
end
