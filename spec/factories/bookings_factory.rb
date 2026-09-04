# == Schema Information
#
# Table name: bookings
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  booking_kind         :string           default("reservation"), not null
#  cancellation_policy  :text
#  confirmation_details :text
#  location             :text
#  lock_version         :integer          default(0), not null
#  notes                :text
#  provider_name        :text             not null
#  starts_at            :datetime         not null
#  status               :string           default("planned"), not null
#  time_zone            :string           default("UTC"), not null
#  title                :text             not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  event_plan_id        :uuid             not null
#  plan_task_id         :uuid
#  user_id              :uuid             not null
#
# Indexes
#
#  index_bookings_on_event_plan_id                           (event_plan_id)
#  index_bookings_on_event_plan_id_and_starts_at_and_id      (event_plan_id,starts_at,id)
#  index_bookings_on_event_plan_id_and_status_and_starts_at  (event_plan_id,status,starts_at)
#  index_bookings_on_unique_plan_task                        (plan_task_id) UNIQUE WHERE (plan_task_id IS NOT NULL)
#  index_bookings_on_user_id                                 (user_id)
#  index_bookings_on_user_id_and_created_at                  (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (event_plan_id => event_plans.id) ON DELETE => cascade
#  fk_rails_...  (plan_task_id => plan_tasks.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :booking do
    association :user
    event_plan { association :event_plan, user:, relationship_profile: association(:relationship_profile, user:) }
    booking_kind { "reservation" }
    title { "Dinner reservation" }
    provider_name { "Casa Verde" }
    starts_at { 2.weeks.from_now.change(min: 0) }
    time_zone { "UTC" }
    location { "Main dining room" }
    status { "planned" }
    confirmation_details { nil }
    cancellation_policy { nil }
    notes { nil }
  end
end
