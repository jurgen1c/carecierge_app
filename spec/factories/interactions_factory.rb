# == Schema Information
#
# Table name: interactions
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  interaction_type        :string           not null
#  notes                   :text
#  occurred_at             :datetime         not null
#  origin                  :string           default("manual"), not null
#  source_type             :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  source_id               :uuid
#
# Indexes
#
#  idx_on_relationship_profile_id_occurred_at_id_afacfa9a3b  (relationship_profile_id,occurred_at DESC,id)
#  index_interactions_on_relationship_profile_id             (relationship_profile_id)
#  index_interactions_on_unique_source                       (source_type,source_id) UNIQUE WHERE (source_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :interaction do
    relationship_profile
    interaction_type { "call" }
    origin { "manual" }
    occurred_at { Time.zone.local(2026, 7, 14, 18, 30, 0) }
    notes { "Caught up about the week." }

    trait :derived_from_conversation_recap do
      origin { "derived" }
      interaction_type { "conversation_recap" }
      association :source, factory: :conversation_recap
      relationship_profile { source.relationship_profile }
      notes { nil }
      occurred_at { source.occurred_at }
    end

    trait :derived_from_mood_note do
      origin { "derived" }
      interaction_type { "mood_note" }
      association :source, factory: :mood_note
      relationship_profile { source.relationship_profile }
      notes { nil }
      occurred_at { source.observed_at }
    end
  end
end
