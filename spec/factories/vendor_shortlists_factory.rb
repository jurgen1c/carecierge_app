# == Schema Information
#
# Table name: vendor_shortlists
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  lock_version            :integer          default(0), not null
#  title                   :text             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  event_plan_id           :uuid
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_vendor_shortlists_on_event_plan_id            (event_plan_id)
#  index_vendor_shortlists_on_profile_and_created_at   (relationship_profile_id,created_at)
#  index_vendor_shortlists_on_relationship_profile_id  (relationship_profile_id)
#  index_vendor_shortlists_on_user_id                  (user_id)
#  index_vendor_shortlists_on_user_id_and_created_at   (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :vendor_shortlist do
    association :user
    relationship_profile { association(:relationship_profile, user:) }
    event_plan { association(:event_plan, user:, relationship_profile:) }
    title { "Birthday dinner options" }

    trait :relationship_need do
      event_plan { nil }
    end
  end
end
