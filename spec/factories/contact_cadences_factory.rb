# == Schema Information
#
# Table name: contact_cadences
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  interval_days           :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_contact_cadences_on_relationship_profile_id  (relationship_profile_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :contact_cadence do
    relationship_profile
    interval_days { 14 }
  end
end
