# == Schema Information
#
# Table name: commitments
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  completed_at            :datetime
#  due_on                  :date
#  notes                   :text
#  status                  :string           default("open"), not null
#  title                   :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_status_due_on_109b7b7dd5  (relationship_profile_id,status,due_on)
#  index_commitments_on_open_due_on                         (status,due_on) WHERE (((status)::text = 'open'::text) AND (due_on IS NOT NULL))
#  index_commitments_on_relationship_profile_id             (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :commitment do
    association :relationship_profile
    title { "Send the article" }
    notes { "Share the link after work." }
    due_on { 2.days.from_now.to_date }
    status { "open" }
  end
end
