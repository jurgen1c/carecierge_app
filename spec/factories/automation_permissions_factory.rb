# == Schema Information
#
# Table name: automation_permissions
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  capability              :string           not null
#  mode                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_automation_permissions_account_defaults              (user_id,capability) UNIQUE WHERE (relationship_profile_id IS NULL)
#  idx_automation_permissions_relationship_overrides        (user_id,relationship_profile_id,capability) UNIQUE WHERE (relationship_profile_id IS NOT NULL)
#  index_automation_permissions_on_relationship_profile_id  (relationship_profile_id)
#  index_automation_permissions_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :automation_permission do
    user
    capability { "draft_messages" }
    mode { "ask_every_time" }

    trait :relationship_override do
      association :relationship_profile, factory: :relationship_profile

      after(:build) do |permission|
        permission.relationship_profile.user = permission.user
      end
    end
  end
end
