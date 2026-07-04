# == Schema Information
#
# Table name: relationship_groups
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_relationship_groups_on_user_id                 (user_id)
#  index_relationship_groups_on_user_id_and_lower_name  (user_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :relationship_group do
    user
    name { "close family" }
  end
end
