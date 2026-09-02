# == Schema Information
#
# Table name: approval_requests
# Database name: primary
#
#  id                 :uuid             not null, primary key
#  action_key         :string           not null
#  confidence         :string
#  decided_at         :datetime
#  deferred_until     :datetime
#  kind               :string           not null
#  lock_version       :integer          default(0), not null
#  risk_level         :string           not null
#  status             :string           default("pending"), not null
#  subject_type       :string           not null
#  subject_updated_at :datetime         not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  subject_id         :uuid             not null
#  user_id            :uuid             not null
#
# Indexes
#
#  idx_approval_requests_one_open_action                         (user_id,subject_type,subject_id,action_key) UNIQUE WHERE ((status)::text = ANY ((ARRAY['pending'::character varying, 'deferred'::character varying])::text[]))
#  index_approval_requests_on_subject                            (subject_type,subject_id)
#  index_approval_requests_on_user_id                            (user_id)
#  index_approval_requests_on_user_id_and_status_and_created_at  (user_id,status,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :approval_request do
    user
    subject { association :extracted_memory, relationship_profile: association(:relationship_profile, user:) }
    kind { "extracted_memory" }
    action_key { "review_extracted_memory" }
    status { "pending" }
    risk_level { "medium" }
    confidence { "medium" }
    subject_updated_at { subject.updated_at }
  end
end
