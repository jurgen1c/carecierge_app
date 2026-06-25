# == Schema Information
#
# Table name: feature_flags
# Database name: primary
#
#  id          :uuid             not null, primary key
#  description :text
#  enabled     :boolean          default(FALSE), not null
#  key         :string           not null
#  metadata    :jsonb            not null
#  name        :string           not null
#  retired_at  :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_feature_flags_on_key         (key) UNIQUE
#  index_feature_flags_on_retired_at  (retired_at)
#
FactoryBot.define do
  factory :feature_flag do
    sequence(:key) { |n| "feature_flag_#{n}" }
    sequence(:name) { |n| "Feature flag #{n}" }
    description { "Controls staged rollout for a Carecierge capability." }
    enabled { false }
  end
end
