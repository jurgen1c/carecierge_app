# == Schema Information
#
# Table name: relationship_profiles
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  archived_at            :datetime
#  birthday               :date
#  first_name             :string           not null
#  last_name              :string
#  notes                  :text
#  preferred_name         :string
#  private_notes          :text
#  pronouns               :string
#  structured_preferences :jsonb            not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  relationship_type_id   :uuid
#  user_id                :uuid             not null
#
# Indexes
#
#  index_relationship_profiles_on_first_name               (first_name)
#  index_relationship_profiles_on_last_name                (last_name)
#  index_relationship_profiles_on_preferred_name           (preferred_name)
#  index_relationship_profiles_on_relationship_type_id     (relationship_type_id)
#  index_relationship_profiles_on_user_id                  (user_id)
#  index_relationship_profiles_on_user_id_and_archived_at  (user_id,archived_at)
#
# Foreign Keys
#
#  fk_rails_...                         (relationship_type_id => relationship_types.id)
#  fk_rails_...                         (user_id => users.id)
#  fk_relationship_profiles_type_owner  ([relationship_type_id, user_id] => relationship_types[id, user_id])
#
FactoryBot.define do
  factory :relationship_profile do
    user
    relationship_type { association(:relationship_type, user:) }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    preferred_name { nil }
    pronouns { nil }
    birthday { nil }
    notes { "Enjoys calm check-ins." }
    private_notes { nil }
    structured_preferences { {} }
    archived_at { nil }
  end
end
