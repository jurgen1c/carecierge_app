# == Schema Information
#
# Table name: memory_records
# Database name: primary
#
#  id                                 :uuid             not null, primary key
#  body                               :text             not null
#  confidence                         :string           default("confirmed"), not null
#  high_impact_automation_approved_at :datetime
#  review_queued_at                   :datetime
#  reviewed_at                        :datetime
#  source                             :string           default("user_confirmed"), not null
#  stale_after                        :date
#  status                             :string           default("active"), not null
#  title                              :string           not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  relationship_profile_id            :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_stale_after_ff6eff736b           (relationship_profile_id,stale_after)
#  index_memory_records_on_relationship_profile_id                 (relationship_profile_id)
#  index_memory_records_on_relationship_profile_id_and_confidence  (relationship_profile_id,confidence)
#  index_memory_records_on_relationship_profile_id_and_source      (relationship_profile_id,source)
#  index_memory_records_on_relationship_profile_id_and_status      (relationship_profile_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
FactoryBot.define do
  factory :memory_record do
    relationship_profile
    title { "Likes jasmine tea" }
    body { "Jasmine tea came up as a calming evening preference." }
    source { "user_confirmed" }
    confidence { "confirmed" }
    status { "active" }
    stale_after { nil }
  end
end
