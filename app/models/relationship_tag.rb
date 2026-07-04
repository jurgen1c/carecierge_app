# == Schema Information
#
# Table name: relationship_tags
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_relationship_tags_on_user_id                 (user_id)
#  index_relationship_tags_on_user_id_and_lower_name  (user_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class RelationshipTag < ApplicationRecord
  belongs_to :user
  has_many :relationship_taggings, dependent: :destroy
  has_many :relationship_profiles, through: :relationship_taggings

  before_validation :normalize_name

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }

  scope :ordered, -> { order(Arel.sql("lower(name) ASC")) }

  private

  def normalize_name
    self.name = name.to_s.strip
  end
end
