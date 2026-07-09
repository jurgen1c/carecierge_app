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
class ConversationRecap < ApplicationRecord
  CAPTURE_SOURCES = %w[typed voice_transcript].freeze
  EXTRACTION_STATUSES = %w[not_requested requested ready_for_review rejected].freeze

  attr_accessor :request_memory_extraction

  belongs_to :relationship_profile
  has_one :timeline_entry, as: :source_record, dependent: :destroy
  has_one_attached :audio_recording

  before_validation :default_occurred_at
  before_validation :normalize_text_fields
  before_save :apply_extraction_request

  validates :title, presence: true
  validates :body, presence: true
  validates :occurred_at, presence: true
  validates :capture_source, presence: true, inclusion: { in: CAPTURE_SOURCES }
  validates :extraction_status, presence: true, inclusion: { in: EXTRACTION_STATUSES }

  scope :ordered, -> { order(occurred_at: :desc, title: :asc, id: :asc) }

  def display_title
    title
  end

  def capture_source_label
    self.class.capture_source_label(capture_source)
  end

  def extraction_status_label
    self.class.extraction_status_label(extraction_status)
  end

  def self.capture_source_options
    CAPTURE_SOURCES.map { |value| [ capture_source_label(value), value ] }
  end

  def self.capture_source_label(value)
    I18n.t("conversation_recaps.capture_sources.#{value}")
  end

  def self.extraction_status_label(value)
    I18n.t("conversation_recaps.extraction_statuses.#{value}")
  end

  private

  def default_occurred_at
    self.occurred_at ||= Time.current
  end

  def normalize_text_fields
    self.title = title.to_s.squish
    self.body = body.to_s.strip
    self.transcript = transcript.to_s.strip.presence
  end

  def apply_extraction_request
    return unless ActiveModel::Type::Boolean.new.cast(request_memory_extraction)
    return unless extraction_status == "not_requested"

    self.extraction_status = "requested"
    self.extraction_requested_at ||= Time.current
  end
end
