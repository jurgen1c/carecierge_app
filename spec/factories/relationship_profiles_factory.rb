# == Schema Information
#
# Table name: relationship_profiles
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  birthday               :date
#  discarded_at           :datetime
#  first_name             :string           not null
#  last_name              :string
#  notes                  :text
#  preferred_name         :string
#  private_notes          :text
#  pronouns               :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  user_id                :uuid             not null
#
# Indexes
#
#  index_relationship_profiles_on_first_name               (first_name)
#  index_relationship_profiles_on_last_name                (last_name)
#  index_relationship_profiles_on_preferred_name           (preferred_name)
#  index_relationship_profiles_on_relationship_type_name   (relationship_type_name)
#  index_relationship_profiles_on_slug                     (slug) UNIQUE
#  index_relationship_profiles_on_user_id                  (user_id)
#  index_relationship_profiles_on_user_id_and_discarded_at (user_id,discarded_at)
#
# Foreign Keys
#
#  fk_rails_...                         (user_id => users.id)
#
FactoryBot.define do
  factory :relationship_profile do
    user
    relationship_type_name { "Friend" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    preferred_name { nil }
    pronouns { nil }
    birthday { nil }
    notes { "Enjoys calm check-ins." }
    private_notes { nil }
    discarded_at { nil }
  end
end
