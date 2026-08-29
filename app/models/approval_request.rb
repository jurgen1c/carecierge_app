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
class ApprovalRequest < ApplicationRecord
  KINDS = %w[
    extracted_memory memory_record message_draft reminder_change automation_action
    vendor_message quote_request booking_confirmation purchase_request deposit_payment
    invitation calendar_invite
  ].freeze
  ACTION_KEYS = %w[review_extracted_memory approve_high_impact_memory].freeze
  STATUSES = %w[pending deferred approved rejected dismissed superseded].freeze
  RISK_LEVELS = %w[low medium high sensitive].freeze
  CONFIDENCES = %w[confirmed high medium low inferred].freeze
  TERMINAL_STATUSES = %w[approved rejected dismissed superseded].freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true
  has_many :approval_decisions, -> { order(occurred_at: :desc, id: :desc) }, dependent: :delete_all
  has_many :targeted_audit_events, as: :target, class_name: "AuditEvent", dependent: :nullify

  validates :kind, inclusion: { in: KINDS }
  validates :action_key, inclusion: { in: ACTION_KEYS }
  validates :status, inclusion: { in: STATUSES }
  validates :risk_level, inclusion: { in: RISK_LEVELS }
  validates :confidence, inclusion: { in: CONFIDENCES }, allow_nil: true
  validates :subject_updated_at, presence: true
  validates :action_key, uniqueness: {
    scope: %i[user_id subject_type subject_id],
    conditions: -> { where(status: %w[pending deferred]) }
  }
  validate :subject_belongs_to_user
  validate :deferred_until_is_future, if: -> { status == "deferred" }

  scope :pending_review, -> {
    where(status: "pending").or(where(status: "deferred", deferred_until: ..Time.current))
      .order(Arel.sql("CASE risk_level WHEN 'sensitive' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END"), :created_at, :id)
  }
  scope :deferred, -> { where(status: "deferred", deferred_until: Time.current..).order(:deferred_until, :id) }
  scope :completed, -> { where(status: TERMINAL_STATUSES).order(decided_at: :desc, id: :desc) }
  scope :open, -> { where(status: %w[pending deferred]) }

  def open_for_decision?
    status == "pending" || status == "deferred" && deferred_until <= Time.current
  end

  private

  def subject_belongs_to_user
    return if subject.blank? || user.blank?
    return if subject_owner_id == user_id

    errors.add(:subject, :owner_mismatch)
  end

  def subject_owner_id
    case subject
    when ExtractedMemory, MemoryRecord then subject.relationship_profile.user_id
    when MessageDraft, Reminder, AutomationPermission then subject.user_id
    end
  end

  def deferred_until_is_future
    errors.add(:deferred_until, :in_future) unless deferred_until.present? && deferred_until > Time.current
  end
end
