# == Schema Information
#
# Table name: social_context_notes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  allow_suggestions       :boolean          default(FALSE), not null
#  analyzed_at             :datetime
#  interpretation          :text
#  interpretation_status   :string           default("not_requested"), not null
#  lock_version            :integer          default(0), not null
#  suggested_uses          :jsonb            not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_created_at_71f3ad1154        (relationship_profile_id,created_at)
#  index_social_context_notes_on_profile_and_suggestion_usage  (relationship_profile_id,allow_suggestions)
#  index_social_context_notes_on_relationship_profile_id       (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :social_context_note do
    relationship_profile
    body { "Maya shared a photo from the neighborhood bookshop." }
    allow_suggestions { false }
    interpretation { nil }
    interpretation_status { "not_requested" }
    suggested_uses { [] }
    analyzed_at { nil }
  end
end
