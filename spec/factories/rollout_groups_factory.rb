# == Schema Information
#
# Table name: rollout_groups
# Database name: primary
#
#  id          :uuid             not null, primary key
#  criteria    :jsonb            not null
#  description :text
#  key         :string           not null
#  name        :string           not null
#  retired_at  :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_rollout_groups_on_key         (key) UNIQUE
#  index_rollout_groups_on_retired_at  (retired_at)
#
FactoryBot.define do
  factory :rollout_group do
    sequence(:key) { |n| "rollout_group_#{n}" }
    sequence(:name) { |n| "Rollout group #{n}" }
    description { "A deterministic rollout group." }
    criteria { { "segment" => "early_access" } }
  end
end
