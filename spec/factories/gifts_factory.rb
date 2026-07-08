# == Schema Information
#
# Table name: gifts
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  given_on                :date
#  name                    :string           not null
#  notes                   :text
#  occasion                :string
#  outcome                 :string
#  price_cents             :integer
#  reaction                :text
#  status                  :string           default("idea"), not null
#  vendor                  :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_gifts_on_relationship_profile_id               (relationship_profile_id)
#  index_gifts_on_relationship_profile_id_and_given_on  (relationship_profile_id,given_on)
#  index_gifts_on_relationship_profile_id_and_outcome   (relationship_profile_id,outcome)
#  index_gifts_on_relationship_profile_id_and_status    (relationship_profile_id,status)
#  index_gifts_on_profile_and_lower_name                (relationship_profile_id, lower((name)::text))
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
FactoryBot.define do
  factory :gift do
    relationship_profile
    name { "Ceramic mug" }
    status { "idea" }
    occasion { "Birthday" }
    price_cents { nil }
    vendor { nil }
    given_on { Date.current if status == "given" }
    reaction { nil }
    outcome { nil }
    notes { nil }
  end
end
