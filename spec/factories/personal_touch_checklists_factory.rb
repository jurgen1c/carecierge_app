# == Schema Information
#
# Table name: personal_touch_checklists
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  event_plan_id           :uuid
#  important_date_id       :uuid
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_personal_touch_checklists_unique_event_plan             (event_plan_id) UNIQUE WHERE (event_plan_id IS NOT NULL)
#  idx_personal_touch_checklists_unique_important_date         (important_date_id) UNIQUE WHERE (important_date_id IS NOT NULL)
#  index_personal_touch_checklists_on_relationship_profile_id  (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (important_date_id => important_dates.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :personal_touch_checklist do
    relationship_profile
    event_plan { association(:event_plan, user: relationship_profile.user, relationship_profile:) }
    important_date { nil }
  end
end
