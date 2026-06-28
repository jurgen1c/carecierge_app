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
