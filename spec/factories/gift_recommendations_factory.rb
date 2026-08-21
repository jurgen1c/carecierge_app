# == Schema Information
#
# Table name: gift_recommendations
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  allow_repeats           :boolean          default(FALSE), not null
#  budget_cents            :integer
#  dismissed_at            :datetime
#  estimated_price_cents   :integer
#  generated_at            :datetime         not null
#  include_private_notes   :boolean          default(FALSE), not null
#  include_vault_context   :boolean          default(FALSE), not null
#  locale                  :string           default("en"), not null
#  lock_version            :integer          default(0), not null
#  needed_by               :date
#  occasion                :text
#  purchased_at            :datetime
#  rationale               :text             not null
#  saved_at                :datetime
#  source_context          :text             not null
#  status                  :string           default("generated"), not null
#  title                   :text             not null
#  vendor                  :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  gift_id                 :uuid
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_gift_recommendations_on_gift_id                   (gift_id)
#  index_gift_recommendations_on_profile_status_generated  (relationship_profile_id,status,generated_at)
#  index_gift_recommendations_on_relationship_profile_id   (relationship_profile_id)
#  index_gift_recommendations_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (gift_id => gifts.id) ON DELETE => nullify
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :gift_recommendation do
    user
    relationship_profile { association :relationship_profile, user: }
    title { "Coffee tasting set" }
    rationale { "It matches a confirmed preference for light-roast coffee." }
    source_context do
      [
        {
          "id" => "preference:#{SecureRandom.uuid}",
          "label" => "Preference",
          "certainty" => "confirmed",
          "sensitive" => false
        }
      ]
    end
    status { "generated" }
    locale { "en" }
    generated_at { Time.current }
  end
end
