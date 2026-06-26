# == Schema Information
#
# Table name: contact_methods
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  kind                    :string           not null
#  label                   :string
#  preferred               :boolean          default(FALSE), not null
#  value                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_contact_methods_on_relationship_profile_id           (relationship_profile_id)
#  index_contact_methods_on_relationship_profile_id_and_kind  (relationship_profile_id,kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
FactoryBot.define do
  factory :contact_method do
    relationship_profile
    kind { "email" }
    value { Faker::Internet.email }
    label { "Personal" }
    preferred { true }
  end
end
