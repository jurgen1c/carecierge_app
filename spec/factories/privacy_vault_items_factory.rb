# == Schema Information
#
# Table name: privacy_vault_items
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  payload                 :text             not null
#  protectable_type        :string           not null
#  protected_at            :datetime         not null
#  suggestion_usage        :string           default("excluded"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  protectable_id          :uuid             not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_protected_at_06b534e13e  (relationship_profile_id,protected_at)
#  index_privacy_vault_items_on_protectable                (protectable_type,protectable_id) UNIQUE
#  index_privacy_vault_items_on_relationship_profile_id    (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :privacy_vault_item do
    relationship_profile
    protectable { association(:memory_record, relationship_profile:) }
    payload { { "title" => "Private memory", "body" => "Protected context" } }
    suggestion_usage { "excluded" }
    protected_at { Time.current }
  end
end
