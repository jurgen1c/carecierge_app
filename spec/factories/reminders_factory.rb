# == Schema Information
#
# Table name: reminders
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  completed_at            :datetime
#  next_delivery_at        :datetime
#  notes                   :text
#  priority                :string           default("normal"), not null
#  recurrence              :string           default("none"), not null
#  recurrence_anchor_at    :datetime         not null
#  reminder_type           :string           default("custom"), not null
#  scheduled_at            :datetime         not null
#  snoozed_until           :datetime
#  status                  :string           default("active"), not null
#  time_zone               :string           default("UTC"), not null
#  title                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commitment_id           :uuid
#  important_date_id       :uuid
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_reminders_on_active_next_delivery_at              (next_delivery_at) WHERE (((status)::text = 'active'::text) AND (next_delivery_at IS NOT NULL))
#  index_reminders_on_commitment_id                        (commitment_id)
#  index_reminders_on_important_date_id                    (important_date_id)
#  index_reminders_on_profile_status_and_schedule          (relationship_profile_id,status,scheduled_at)
#  index_reminders_on_relationship_profile_id              (relationship_profile_id)
#  index_reminders_on_user_id                              (user_id)
#  index_reminders_on_user_id_and_status_and_scheduled_at  (user_id,status,scheduled_at)
#
# Foreign Keys
#
#  fk_rails_...  (commitment_id => commitments.id) ON DELETE => nullify
#  fk_rails_...  (important_date_id => important_dates.id) ON DELETE => nullify
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :reminder do
    user
    relationship_profile { association :relationship_profile, user: user }
    important_date { nil }
    title { "Call Elena" }
    notes { "Ask how the new role is going." }
    reminder_type { "check_in" }
    priority { "normal" }
    recurrence { "none" }
    status { "active" }
    scheduled_at { Time.zone.local(2026, 7, 14, 16, 30) }
    next_delivery_at { scheduled_at }
    snoozed_until { nil }
    completed_at { nil }
  end
end
