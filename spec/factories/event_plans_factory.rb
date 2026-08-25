# == Schema Information
#
# Table name: event_plans
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  budget_cents            :integer
#  completed_at            :datetime
#  effort_level            :string           default("medium"), not null
#  generation_version      :bigint           default(0), not null
#  guest_list              :text
#  lock_version            :integer          default(0), not null
#  notes                   :text
#  occasion_type           :string           not null
#  source_context          :text             not null
#  starts_on               :date
#  status                  :string           default("active"), not null
#  title                   :text             not null
#  tone                    :string           default("warm"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_event_plans_on_profile_status_and_start          (relationship_profile_id,status,starts_on)
#  index_event_plans_on_relationship_profile_id           (relationship_profile_id)
#  index_event_plans_on_user_id                           (user_id)
#  index_event_plans_on_user_id_and_status_and_starts_on  (user_id,status,starts_on)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :event_plan do
    association :user
    relationship_profile { association(:relationship_profile, user:) }
    title { "Maya's birthday dinner" }
    occasion_type { "birthday" }
    starts_on { Date.new(2026, 9, 12) }
    budget_cents { 15_000 }
    guest_list { "Maya, Alex, and Jordan" }
    notes { "Keep the evening relaxed." }
    status { "active" }
    source_context { [] }
  end
end
