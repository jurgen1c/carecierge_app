# == Schema Information
#
# Table name: mood_notes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  category                :string           not null
#  follow_up_at            :datetime
#  observation             :text             not null
#  observed_at             :datetime         not null
#  supportive_action       :text
#  timeline_visible        :boolean          default(FALSE), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_mood_notes_on_relationship_profile_id                   (relationship_profile_id)
#  index_mood_notes_on_relationship_profile_id_and_category      (relationship_profile_id,category)
#  index_mood_notes_on_relationship_profile_id_and_follow_up_at  (relationship_profile_id,follow_up_at)
#  index_mood_notes_on_relationship_profile_id_and_observed_at   (relationship_profile_id,observed_at)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
FactoryBot.define do
  factory :mood_note do
    relationship_profile
    category { "stressed" }
    observation { "Seemed quieter than usual after work." }
    observed_at { Time.zone.local(2026, 7, 12, 18, 30, 0) }
    supportive_action { "Send a low-pressure check-in tomorrow." }
    follow_up_at { Time.zone.local(2026, 7, 13, 10, 0, 0) }
    timeline_visible { false }
  end
end
