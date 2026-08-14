# == Schema Information
#
# Table name: social_context_notes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  allow_suggestions       :boolean          default(FALSE), not null
#  analyzed_at             :datetime
#  interpretation          :text
#  interpretation_status   :string           default("not_requested"), not null
#  lock_version            :integer          default(0), not null
#  suggested_uses          :jsonb            not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_created_at_71f3ad1154        (relationship_profile_id,created_at)
#  index_social_context_notes_on_profile_and_suggestion_usage  (relationship_profile_id,allow_suggestions)
#  index_social_context_notes_on_relationship_profile_id       (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
class SocialContextNote < ApplicationRecord
  MAX_BODY_CHARACTERS = 5_000
  MAX_BODY_HTML_BYTES = 64.kilobytes
  MAX_INTERPRETATION_CHARACTERS = 2_000
  MAX_IMAGES = 3
  MAX_IMAGE_BYTES = 10.megabytes
  DOWNSTREAM_SOURCE_LIMIT = 10
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
  INTERPRETATION_STATUSES = %w[not_requested draft approved].freeze
  SUGGESTED_USES = %w[gift message conversation_topic reminder].freeze

  belongs_to :relationship_profile
  has_rich_text :body

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :suggestion_allowed, -> { where(allow_suggestions: true) }
  scope :downstream_sources, -> { suggestion_allowed.with_rich_text_body.recent_first.limit(DOWNSTREAM_SOURCE_LIMIT) }

  validates :interpretation_status, inclusion: { in: INTERPRETATION_STATUSES }
  validates :interpretation, length: { maximum: MAX_INTERPRETATION_CHARACTERS }, allow_nil: true
  validate :body_has_text
  validate :body_is_bounded
  validate :body_html_is_bounded
  validate :embedded_images_are_managed
  validate :embedded_images_are_supported
  validate :suggested_uses_are_supported

  def image_blobs
    body.body&.attachables&.grep(ActiveStorage::Blob) || []
  end

  def self.select_downstream_sources(notes)
    Array(notes)
      .select(&:allow_suggestions?)
      .sort_by { |note| [ note.created_at, note.id ] }
      .reverse
      .first(DOWNSTREAM_SOURCE_LIMIT)
  end

  def display_title
    body.to_plain_text.squish.truncate(80)
  end

  def downstream_context
    return unless allow_suggestions?

    [
      body.to_plain_text.squish,
      (interpretation.to_s.squish if interpretation_status == "approved")
    ].compact_blank.join(" ")
  end

  def message_draft_context_signature
    return unless allow_suggestions?

    [
      body.to_plain_text.squish,
      (interpretation.to_s.squish if approved_suggested_uses.include?("message"))
    ].compact_blank
  end

  def approved_suggested_uses
    return [] unless allow_suggestions? && interpretation_status == "approved"

    suggested_uses
  end

  def suggestion_evidence
    return interpretation.to_s.squish if interpretation_status == "approved" && interpretation.present?

    body.to_plain_text.squish
  end

  def suggestion_certainty
    interpretation_status == "approved" && interpretation.present? ? "inferred" : "confirmed"
  end

  def update_from_user!(attributes, approve_interpretation: false)
    with_active_relationship_lock do
      previous_message_draft_context = message_draft_context_signature
      attributes = attributes.to_h.symbolize_keys
      source_changed = attributes.key?(:body) &&
        source_signature(ActionText::Content.new(attributes[:body].to_s)) != source_signature(body.body)

      if source_changed
        reset_interpretation
        attributes.delete(:interpretation)
        attributes.delete(:suggested_uses)
        approve_interpretation = false
      end
      assign_attributes(attributes)
      if attributes.key?(:interpretation) && interpretation.blank?
        reset_interpretation
      elsif approve_interpretation && interpretation.present?
        self.interpretation_status = "approved"
        self.interpretation = interpretation.to_s.squish
      end
      save!
      cancel_in_flight_message_draft_generations_if_changed!(previous_message_draft_context)
    end
  end

  def destroy_from_user!
    with_active_relationship_lock do
      blobs = image_blobs.to_a
      used_by_message_drafts = message_draft_context_signature.present?
      destroy!
      relationship_profile.cancel_in_flight_message_draft_generations! if used_by_message_drafts
      blobs
    end
  end

  def save_from_user
    with_active_relationship_lock do
      save.tap do |persisted|
        if persisted && message_draft_context_signature.present?
          relationship_profile.cancel_in_flight_message_draft_generations!
        end
      end
    end
  end

  def clear_ai_analysis_for_deletion!
    previous_message_draft_context = message_draft_context_signature
    reset_interpretation
    has_changes_to_save? ? save! : touch
    previous_message_draft_context != message_draft_context_signature
  end

  private

  def reset_interpretation
    self.interpretation = nil
    self.interpretation_status = "not_requested"
    self.suggested_uses = []
    self.analyzed_at = nil
  end

  def cancel_in_flight_message_draft_generations_if_changed!(previous_context)
    return if previous_context == message_draft_context_signature

    relationship_profile.cancel_in_flight_message_draft_generations!
  end

  def with_active_relationship_lock
    relationship_profile.with_lock do
      raise ActiveRecord::RecordNotFound if relationship_profile.discarded?

      yield
    end
  end

  def source_signature(content)
    [ content.to_plain_text.squish, content.attachables.grep(ActiveStorage::Blob).map(&:id) ]
  end

  def body_has_text
    errors.add(:body, :blank) if body.to_plain_text.squish.blank?
  end

  def body_is_bounded
    return if body.to_plain_text.length <= MAX_BODY_CHARACTERS

    errors.add(:body, :too_long, count: MAX_BODY_CHARACTERS)
  end

  def body_html_is_bounded
    return if body.body.nil? || body.body.to_html.bytesize <= MAX_BODY_HTML_BYTES

    errors.add(:body, :html_too_large, count: MAX_BODY_HTML_BYTES)
  end

  def embedded_images_are_managed
    return if body.body.nil? || body.body.fragment.find_all("img").empty?

    errors.add(:body, :unmanaged_image)
  end

  def embedded_images_are_supported
    attachables = body.body&.attachables || []
    errors.add(:body, :unsupported_attachment) unless attachables.all?(ActiveStorage::Blob)
    blobs = attachables.grep(ActiveStorage::Blob)
    errors.add(:body, :too_many_attachments, count: MAX_IMAGES) if blobs.size > MAX_IMAGES

    blobs.each do |blob|
      errors.add(:body, :unsupported_attachment) unless blob.content_type.in?(IMAGE_CONTENT_TYPES)
      errors.add(:body, :attachment_too_large, count: MAX_IMAGE_BYTES) if blob.byte_size > MAX_IMAGE_BYTES
    end
  end

  def suggested_uses_are_supported
    unless suggested_uses.is_a?(Array) &&
        suggested_uses.size <= SUGGESTED_USES.size &&
        suggested_uses.uniq.size == suggested_uses.size &&
        suggested_uses.all? { |value| value.is_a?(String) && value.in?(SUGGESTED_USES) }
      errors.add(:suggested_uses, :inclusion)
    end
  end
end
