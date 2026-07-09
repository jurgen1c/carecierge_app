# == Schema Information
#
# Table name: conversation_recaps
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  body                    :text             not null
#  capture_source          :string           default("typed"), not null
#  extraction_approved_at  :datetime
#  extraction_requested_at :datetime
#  extraction_status       :string           default("not_requested"), not null
#  occurred_at             :datetime         not null
#  title                   :string           not null
#  transcript              :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_capture_source_0d8af56d63     (relationship_profile_id,capture_source)
#  idx_on_relationship_profile_id_extraction_status_90ce435e9b  (relationship_profile_id,extraction_status)
#  idx_on_relationship_profile_id_occurred_at_74ae112d81        (relationship_profile_id,occurred_at)
#  index_conversation_recaps_on_relationship_profile_id         (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
FactoryBot.define do
  factory :conversation_recap do
    relationship_profile
    title { "Lunch with David" }
    body { "Talked about job changes and book recommendations." }
    occurred_at { Time.zone.local(2026, 7, 8, 12, 30, 0) }
    capture_source { "typed" }
    transcript { nil }
    extraction_status { "not_requested" }
    extraction_requested_at { nil }
    extraction_approved_at { nil }
  end
end
