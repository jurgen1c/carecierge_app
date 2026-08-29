# == Schema Information
#
# Table name: extracted_memories
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  body                       :text             not null
#  category                   :string           not null
#  confidence                 :string           not null
#  corrected_body             :text
#  corrected_title            :string
#  reviewed_at                :datetime
#  source_excerpt             :text             not null
#  status                     :string           default("pending"), not null
#  title                      :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  canonical_memory_record_id :uuid
#  conversation_recap_id      :uuid             not null
#  relationship_profile_id    :uuid             not null
#  reviewed_by_id             :uuid
#
# Indexes
#
#  index_extracted_memories_on_canonical_memory_record_id          (canonical_memory_record_id) UNIQUE
#  index_extracted_memories_on_conversation_recap_id               (conversation_recap_id)
#  index_extracted_memories_on_conversation_recap_id_and_status    (conversation_recap_id,status)
#  index_extracted_memories_on_relationship_profile_id             (relationship_profile_id)
#  index_extracted_memories_on_relationship_profile_id_and_status  (relationship_profile_id,status)
#  index_extracted_memories_on_reviewed_by_id                      (reviewed_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (canonical_memory_record_id => memory_records.id) ON DELETE => nullify
#  fk_rails_...  (conversation_recap_id => conversation_recaps.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (reviewed_by_id => users.id) ON DELETE => nullify
#
class ExtractedMemory < ApplicationRecord
  CATEGORIES = %w[preference important_date desire commitment gift_idea boundary emotional_context].freeze
  CONFIDENCES = %w[high medium low inferred].freeze
  STATUSES = %w[pending approved rejected corrected].freeze

  belongs_to :relationship_profile
  belongs_to :conversation_recap
  belongs_to :reviewed_by, class_name: "User", optional: true
  belongs_to :canonical_memory_record, class_name: "MemoryRecord", optional: true
  has_many :approval_requests, as: :subject, dependent: :destroy

  before_validation :normalize_text_fields

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :confidence, presence: true, inclusion: { in: CONFIDENCES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :title, :body, :source_excerpt, presence: true
  validates :corrected_title, :corrected_body, presence: true, if: :corrected?
  validate :conversation_recap_matches_profile

  scope :pending_review, -> { where(status: "pending").order(:created_at, :id) }
  scope :reviewed, -> { where.not(status: "pending").order(reviewed_at: :desc, id: :desc) }

  STATUSES.each { |value| define_method("#{value}?") { status == value } }

  def display_title
    corrected? ? corrected_title : title
  end

  def category_label
    I18n.t("extracted_memories.categories.#{category}")
  end

  def confidence_label
    I18n.t("extracted_memories.confidences.#{confidence}")
  end

  private

  def normalize_text_fields
    self.title = title.to_s.squish
    self.body = body.to_s.strip
    self.source_excerpt = source_excerpt.to_s.strip
    self.corrected_title = corrected_title.to_s.squish.presence
    self.corrected_body = corrected_body.to_s.strip.presence
  end

  def conversation_recap_matches_profile
    return if conversation_recap.blank? || relationship_profile.blank?
    return if conversation_recap.relationship_profile_id == relationship_profile_id

    errors.add(:conversation_recap, :same_relationship_profile)
  end
end
