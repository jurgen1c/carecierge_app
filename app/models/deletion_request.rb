# == Schema Information
#
# Table name: deletion_requests
# Database name: primary
#
#  id             :uuid             not null, primary key
#  account_digest :string           not null
#  completed_at   :datetime
#  request_kind   :string           not null
#  requested_at   :datetime         not null
#  status         :string           default("pending"), not null
#  subject_type   :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  subject_id     :uuid
#  user_id        :uuid
#
# Indexes
#
#  index_deletion_requests_on_request_kind_and_requested_at  (request_kind,requested_at)
#  index_deletion_requests_on_subject_type_and_subject_id    (subject_type,subject_id)
#  index_deletion_requests_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
class DeletionRequest < ApplicationRecord
  REQUEST_KINDS = %w[relationship_profile privacy_vault_item ai_generated account].freeze
  STATUSES = %w[pending completed failed].freeze

  belongs_to :user, optional: true

  validates :request_kind, inclusion: { in: REQUEST_KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :account_digest, :requested_at, presence: true
  validates :subject_type, presence: true, if: -> { subject_id.present? }
  validates :subject_id, presence: true, if: -> { subject_type.present? }

  scope :recent_first, -> { order(requested_at: :desc, created_at: :desc) }
end
