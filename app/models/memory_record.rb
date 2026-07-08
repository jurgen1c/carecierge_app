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
class MemoryRecord < ApplicationRecord
  SOURCES = %w[user_confirmed ai_inferred imported user_corrected].freeze
  CONFIDENCES = %w[confirmed high medium low inferred].freeze
  STATUSES = %w[active needs_review stale corrected archived].freeze

  belongs_to :relationship_profile
  has_many :memory_revisions, dependent: :destroy

  before_validation :normalize_text_fields

  validates :title, presence: true
  validates :body, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :confidence, presence: true, inclusion: { in: CONFIDENCES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :ordered, -> { order(Arel.sql("CASE status WHEN 'needs_review' THEN 0 WHEN 'stale' THEN 1 WHEN 'active' THEN 2 WHEN 'corrected' THEN 3 ELSE 4 END"), :title) }

  def source_label
    self.class.source_label(source)
  end

  def confidence_label
    self.class.confidence_label(confidence)
  end

  def status_label
    self.class.status_label(status)
  end

  def stale?
    stale_after.present? && stale_after < Date.current
  end

  def review_required?
    status.in?(%w[needs_review stale]) || stale?
  end

  def high_impact_automation_allowed?
    return true if high_impact_automation_approved_at.present?

    source == "user_confirmed" && confidence.in?(%w[confirmed high medium])
  end

  def high_impact_automation_blocked?
    !high_impact_automation_allowed?
  end

  def queue_review_if_stale!
    return false unless stale?
    return false if status == "archived"

    update!(status: "needs_review", review_queued_at: Time.current)
  end

  def mark_reviewed!
    update!(status: "active", confidence: "confirmed", reviewed_at: Time.current, review_queued_at: nil, stale_after: nil)
  end

  def approve_high_impact_automation!
    update!(high_impact_automation_approved_at: Time.current)
  end

  def self.source_options
    SOURCES.map { |value| [ source_label(value), value ] }
  end

  def self.confidence_options
    CONFIDENCES.map { |value| [ confidence_label(value), value ] }
  end

  def self.status_options
    STATUSES.map { |value| [ status_label(value), value ] }
  end

  def self.source_label(value)
    I18n.t("memory_records.sources.#{value}")
  end

  def self.confidence_label(value)
    I18n.t("memory_records.confidences.#{value}")
  end

  def self.status_label(value)
    I18n.t("memory_records.statuses.#{value}")
  end

  private

  def normalize_text_fields
    self.title = title.to_s.squish
    self.body = body.to_s.strip
  end
end
