# == Schema Information
#
# Table name: relationship_preferences
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  category                :string           default("general"), not null
#  confidence              :string           default("inferred"), not null
#  key                     :string           not null
#  learned_on              :date
#  preference_type         :string           default("neutral"), not null
#  source_notes            :text
#  value                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_category_de91ce2a16         (relationship_profile_id,category)
#  idx_on_relationship_profile_id_confidence_1dd4e61f57       (relationship_profile_id,confidence)
#  idx_on_relationship_profile_id_preference_type_3701ad82f6  (relationship_profile_id,preference_type)
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
    preference_type { "positive" }
    category { "food" }
    key { "Coffee" }
    value { "decaf" }
    confidence { "inferred" }
  end
end
