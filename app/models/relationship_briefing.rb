# == Schema Information
#
# Table name: relationship_briefings
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  context_categories      :jsonb            not null
#  dismissed_at            :datetime
#  generated_at            :datetime         not null
#  include_private_notes   :boolean          default(FALSE), not null
#  include_vault_context   :boolean          default(FALSE), not null
#  interaction_context     :text             not null
#  locale                  :string           default("en"), not null
#  lock_version            :integer          default(0), not null
#  saved_at                :datetime
#  sections                :text             not null
#  status                  :string           default("generated"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_relationship_briefings_on_one_generated_per_profile  (relationship_profile_id) UNIQUE WHERE ((status)::text = 'generated'::text)
#  index_relationship_briefings_on_profile_and_generated_at   (relationship_profile_id,generated_at DESC)
#  index_relationship_briefings_on_relationship_profile_id    (relationship_profile_id)
#  index_relationship_briefings_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class RelationshipBriefing < ApplicationRecord
  MAX_INTERACTION_CONTEXT_LENGTH = 600
  MAX_SECTIONS = 6
  MAX_ITEMS_PER_SECTION = 5
  MAX_ITEM_LENGTH = 500
  MAX_SOURCE_LABEL_LENGTH = 200
  SECTION_KEYS = %w[
    recent_activity
    commitments
    important_dates
    preferences
    conversation_topics
    sensitive_context
  ].freeze
  STATUSES = %w[generated saved dismissed].freeze
  CERTAINTIES = %w[confirmed inferred].freeze
  LOCALES = %w[en es].freeze

  belongs_to :user
  belongs_to :relationship_profile

  serialize :sections, coder: JSON
  encrypts :interaction_context
  encrypts :sections

  before_validation :normalize_interaction_context

  validates :interaction_context, presence: true, length: { maximum: MAX_INTERACTION_CONTEXT_LENGTH }
  validates :status, inclusion: { in: STATUSES }
  validates :locale, inclusion: { in: LOCALES }
  validates :generated_at, presence: true
  validate :relationship_profile_belongs_to_user
  validate :sections_are_supported

  scope :visible, -> { where.not(status: "dismissed") }
  scope :recent_first, -> { order(generated_at: :desc, created_at: :desc, id: :desc) }

  STATUSES.each { |value| define_method("#{value}?") { status == value } }

  def save_for_later!(at: Time.current)
    with_lock do
      raise ActiveRecord::RecordInvalid, self if dismissed?

      update!(status: "saved", saved_at: saved_at || at)
    end
  end

  def dismiss!(at: Time.current)
    with_lock do
      return self if dismissed?

      update!(status: "dismissed", dismissed_at: at)
    end
  end

  private

  def normalize_interaction_context
    self.interaction_context = interaction_context.to_s.squish
  end

  def relationship_profile_belongs_to_user
    return if user.blank? || relationship_profile.blank?
    return if relationship_profile.user_id == user_id

    errors.add(:relationship_profile, :owner_mismatch)
  end

  def sections_are_supported
    unless sections.is_a?(Array) && sections.length <= MAX_SECTIONS
      errors.add(:sections, :invalid)
      return
    end

    section_keys = sections.filter_map { |section| section["key"] if section.is_a?(Hash) }
    valid = section_keys.length == sections.length &&
      section_keys.uniq.length == section_keys.length &&
      section_keys.all? { |key| key.in?(SECTION_KEYS) } &&
      sections.all? { |section| valid_section?(section) }
    errors.add(:sections, :invalid) unless valid
  end

  def valid_section?(section)
    items = section["items"]
    items.is_a?(Array) && items.length <= MAX_ITEMS_PER_SECTION && items.all? { |item| valid_item?(item) }
  end

  def valid_item?(item)
    return false unless item.is_a?(Hash)
    return false unless item["body"].is_a?(String) && item["body"].present? && item["body"].length <= MAX_ITEM_LENGTH
    return false unless item["certainty"].in?(CERTAINTIES)

    sources = item["sources"]
    sources.is_a?(Array) && sources.present? && sources.all? { |source| valid_source?(source) }
  end

  def valid_source?(source)
    source.is_a?(Hash) &&
      source["id"].is_a?(String) && source["id"].present? &&
      source["label"].is_a?(String) && source["label"].present? &&
      source["label"].length <= MAX_SOURCE_LABEL_LENGTH &&
      [ true, false ].include?(source["sensitive"])
  end
end
