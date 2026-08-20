# == Schema Information
#
# Table name: suggestion_feedbacks
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  acted_at                :datetime
#  dismissed_at            :datetime
#  feedback                :string
#  fingerprint             :string           not null
#  saved_at                :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_dismissed_at_d046df9002  (relationship_profile_id,dismissed_at)
#  index_suggestion_feedbacks_on_relationship_profile_id   (relationship_profile_id)
#  index_suggestion_feedbacks_on_user_id                   (user_id)
#  index_suggestion_feedbacks_on_user_id_and_fingerprint   (user_id,fingerprint) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :suggestion_feedback do
    association :user
    relationship_profile { association(:relationship_profile, user:) }
    fingerprint { SecureRandom.hex(32) }
  end
end
