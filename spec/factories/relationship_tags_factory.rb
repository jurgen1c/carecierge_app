# == Schema Information
#
# Table name: relationship_tags
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  name                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_relationship_tags_on_profile_id_and_lower_name  (relationship_profile_id, lower((name)::text)) UNIQUE
#  index_relationship_tags_on_relationship_profile_id    (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
FactoryBot.define do
  factory :relationship_tag do
    relationship_profile
    name { "family" }
  end
end
