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
FactoryBot.define do
  factory :relationship_preference do
    relationship_profile
    key { "Coffee" }
    value { "decaf" }
  end
end
