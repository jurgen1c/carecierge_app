# == Schema Information
#
# Table name: important_dates
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  date_type               :string           not null
#  importance_level        :string           default("normal"), not null
#  notes                   :text
#  recurrence              :string           default("none"), not null
#  reminder_schedule       :string           default("none"), not null
#  starts_on               :date             not null
#  title                   :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_importance_level_a07d6afa11      (relationship_profile_id,importance_level)
#  index_important_dates_on_relationship_profile_id                (relationship_profile_id)
#  index_important_dates_on_relationship_profile_id_and_date_type  (relationship_profile_id,date_type)
#  index_important_dates_on_relationship_profile_id_and_starts_on  (relationship_profile_id,starts_on)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
FactoryBot.define do
  factory :important_date do
    relationship_profile
    date_type { "birthday" }
    title { nil }
    starts_on { Date.new(2026, 7, 25) }
    recurrence { "yearly" }
    importance_level { "normal" }
    reminder_schedule { "week_before" }
    notes { nil }
  end
end
