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
class TimelineEntry < ApplicationRecord
  ENTRY_TYPES = %w[
    note
    conversation_recap
    mood_note
    gift
    event
    promise
    reminder
    conflict
    apology
    important_date
    plan
    booking
    ai_extraction
    user_correction
  ].freeze
  ORIGINS = %w[manual system].freeze

  belongs_to :relationship_profile
  belongs_to :source_record, polymorphic: true, optional: true

  before_validation :normalize_text_fields

  validates :entry_type, presence: true, inclusion: { in: ENTRY_TYPES }
  validates :origin, presence: true, inclusion: { in: ORIGINS }
  validates :title, presence: true
  validates :occurred_at, presence: true
  validate :source_record_reference_complete
  validate :source_record_matches_relationship_profile

  scope :ordered, -> { order(occurred_at: :desc, title: :asc, id: :asc) }
  scope :of_type, ->(entry_type) {
    ENTRY_TYPES.include?(entry_type.to_s) ? where(entry_type:) : all
  }

  def entry_type_label
    self.class.entry_type_label(entry_type)
  end

  def origin_label
    self.class.origin_label(origin)
  end

  def source_record_label
    return unless source_record

    I18n.t(
      "timeline_entries.source_record",
      type: source_record.model_name.human,
      title: source_record_title
    )
  end

  def self.entry_type_options
    ENTRY_TYPES.map { |value| [ entry_type_label(value), value ] }
  end

  def self.filter_options
    [ [ I18n.t("timeline_entries.filters.all"), nil ] ] + entry_type_options
  end

  def self.entry_type_label(value)
    I18n.t("timeline_entries.entry_types.#{value}")
  end

  def self.origin_label(value)
    I18n.t("timeline_entries.origins.#{value}")
  end

  private

  def normalize_text_fields
    self.title = title.to_s.squish
    self.body = body.to_s.strip.presence
  end

  def source_record_reference_complete
    return if source_record_type.blank? && source_record_id.blank?
    return if source_record_reference_complete?

    errors.add(:source_record, :complete_reference)
  end

  def source_record_matches_relationship_profile
    return unless source_record_reference_complete?
    return if source_record.blank?
    return unless source_record.respond_to?(:relationship_profile_id)
    return if source_record.relationship_profile_id.to_s == relationship_profile_id.to_s

    errors.add(:source_record, :same_relationship_profile)
  end

  def source_record_reference_complete?
    source_record_type.present? && source_record_id.present?
  end

  def source_record_title
    if source_record.respond_to?(:display_title)
      source_record.display_title
    elsif source_record.respond_to?(:display_name)
      source_record.display_name
    elsif source_record.respond_to?(:name)
      source_record.name
    elsif source_record.respond_to?(:title)
      source_record.title
    else
      source_record.model_name.human
    end
  end
end
