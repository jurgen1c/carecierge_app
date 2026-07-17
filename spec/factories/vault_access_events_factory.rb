# == Schema Information
#
# Table name: vault_access_events
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  event_type              :string           not null
#  occurred_at             :datetime         not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  privacy_vault_item_id   :uuid
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_occurred_at_dc7b578e55  (relationship_profile_id,occurred_at)
#  index_vault_access_events_on_privacy_vault_item_id     (privacy_vault_item_id)
#  index_vault_access_events_on_relationship_profile_id   (relationship_profile_id)
#  index_vault_access_events_on_user_id                   (user_id)
#  index_vault_access_events_on_user_id_and_occurred_at   (user_id,occurred_at)
#
# Foreign Keys
#
#  fk_rails_...  (privacy_vault_item_id => privacy_vault_items.id) ON DELETE => nullify
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :vault_access_event do
    user
    relationship_profile { association :relationship_profile, user: }
    event_type { "viewed" }
    occurred_at { Time.current }
  end
end
