# == Schema Information
#
# Table name: message_drafts
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  draft_type              :string           not null
#  formality               :string           default("balanced"), not null
#  response_length         :string           default("medium"), not null
#  situation               :text             default(""), not null
#  tone                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_message_drafts_on_relationship_profile_id  (relationship_profile_id) UNIQUE
#  index_message_drafts_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :message_draft do
    user
    relationship_profile { association(:relationship_profile, user:) }
    draft_type { "birthday" }
    tone { "warm" }
    situation { "" }
    response_length { "medium" }
    formality { "balanced" }
  end

  factory :draft_revision do
    message_draft
    sequence(:position) { |number| number }
    origin { "generated" }
    content { "Happy birthday! I hope today feels thoughtful and unhurried." }
    context_categories { %w[profile important_dates] }
  end
end
