# == Schema Information
#
# Table name: relationship_briefings
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  context_categories      :jsonb            not null
#  dismissed_at            :datetime
#  generated_at            :datetime         not null
#  include_private_notes   :boolean          default(FALSE), not null
#  include_vault_context   :boolean          default(FALSE), not null
#  interaction_context     :text             not null
#  locale                  :string           default("en"), not null
#  lock_version            :integer          default(0), not null
#  saved_at                :datetime
#  sections                :text             not null
#  status                  :string           default("generated"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_relationship_briefings_on_one_generated_per_profile  (relationship_profile_id) UNIQUE WHERE ((status)::text = 'generated'::text)
#  index_relationship_briefings_on_profile_and_generated_at   (relationship_profile_id,generated_at DESC)
#  index_relationship_briefings_on_relationship_profile_id    (relationship_profile_id)
#  index_relationship_briefings_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :relationship_briefing do
    user
    relationship_profile { association :relationship_profile, user: }
    interaction_context { "Dinner after her first week at the new job" }
    status { "generated" }
    locale { "en" }
    context_categories { %w[timeline commitments] }
    sections do
      [
        {
          "key" => "recent_activity",
          "items" => [
            {
              "body" => "She started a new role.",
              "certainty" => "confirmed",
              "sources" => [
                {
                  "id" => "timeline:#{SecureRandom.uuid}",
                  "label" => "Timeline entry from May 22",
                  "sensitive" => false
                }
              ]
            }
          ]
        }
      ]
    end
    generated_at { Time.current }
  end
end
