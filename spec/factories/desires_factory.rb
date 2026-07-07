# == Schema Information
#
# Table name: desires
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  captured_on             :date
#  category                :string           not null
#  notes                   :text
#  source                  :string           default("manual"), not null
#  status                  :string           default("active"), not null
#  title                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_desires_on_relationship_profile_id                  (relationship_profile_id)
#  index_desires_on_relationship_profile_id_and_captured_on  (relationship_profile_id,captured_on)
#  index_desires_on_relationship_profile_id_and_category     (relationship_profile_id,category)
#  index_desires_on_relationship_profile_id_and_status       (relationship_profile_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
FactoryBot.define do
  factory :desire do
    relationship_profile
    title { "Try pottery" }
    category { "activity" }
    status { "active" }
    source { "manual" }
    captured_on { Date.new(2026, 7, 7) }
    notes { nil }
  end
end
