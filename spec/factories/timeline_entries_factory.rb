# == Schema Information
#
# Table name: timeline_entries
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  body                    :text
#  entry_type              :string           not null
#  occurred_at             :datetime         not null
#  origin                  :string           default("manual"), not null
#  source_record_type      :string
#  title                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  source_record_id        :uuid
#
# Indexes
#
#  idx_on_relationship_profile_id_entry_type_7a425876dd          (relationship_profile_id,entry_type)
#  idx_on_relationship_profile_id_occurred_at_81b70cd1a8         (relationship_profile_id,occurred_at)
#  idx_on_source_record_type_source_record_id_f700104f25         (source_record_type,source_record_id)
#  index_timeline_entries_on_relationship_profile_id             (relationship_profile_id)
#  index_timeline_entries_on_relationship_profile_id_and_origin  (relationship_profile_id,origin)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
FactoryBot.define do
  factory :timeline_entry do
    relationship_profile
    entry_type { "note" }
    title { "Checked in after dinner" }
    body { "Talked about plans for next weekend." }
    occurred_at { Time.zone.local(2026, 7, 8, 18, 30, 0) }
    origin { "manual" }
    source_record { nil }
  end
end
