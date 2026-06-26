# == Schema Information
#
# Table name: relationship_notes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  body                    :text             not null
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
  belongs_to :relationship_profile

  validates :body, presence: true
end
