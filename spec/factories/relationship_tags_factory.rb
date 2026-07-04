# == Schema Information
#
# Table name: relationship_tags
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
#  index_relationship_tags_on_user_id                 (user_id)
#  index_relationship_tags_on_user_id_and_lower_name  (user_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :relationship_tag do
    transient do
      relationship_profile { nil }
    end

    user { relationship_profile&.user || association(:user) }
    name { "family" }

    after(:create) do |relationship_tag, evaluator|
      if evaluator.relationship_profile.present?
        create(:relationship_tagging, relationship_profile: evaluator.relationship_profile, relationship_tag:)
      end
    end
  end
end
