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
FactoryBot.define do
  factory :relationship_tagging do
    relationship_profile
    relationship_tag { association(:relationship_tag, user: relationship_profile.user) }
  end
end
