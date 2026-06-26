# == Schema Information
#
# Table name: relationship_types
# Database name: primary
#
#  id          :uuid             not null, primary key
#  active      :boolean          default(TRUE), not null
#  description :text
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :uuid             not null
#
# Indexes
#
#  index_relationship_types_on_id_and_user_id          (id,user_id) UNIQUE
#  index_relationship_types_on_user_id                 (user_id)
#  index_relationship_types_on_user_id_and_lower_name  (user_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :relationship_type do
    user
    sequence(:name) { |number| "Friend #{number}" }
    description { "Personal relationship" }
    active { true }
  end
end
