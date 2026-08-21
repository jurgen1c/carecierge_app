# Generated gift recommendation retained for user review and explicit lifecycle actions.
# == Schema Information
#
# Table name: gift_recommendations
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  allow_repeats           :boolean          default(FALSE), not null
#  budget_cents            :integer
#  dismissed_at            :datetime
#  estimated_price_cents   :integer
#  generated_at            :datetime         not null
#  include_private_notes   :boolean          default(FALSE), not null
#  include_vault_context   :boolean          default(FALSE), not null
#  locale                  :string           default("en"), not null
#  lock_version            :integer          default(0), not null
#  needed_by               :date
#  occasion                :text
#  purchased_at            :datetime
#  rationale               :text             not null
#  saved_at                :datetime
#  source_context          :text             not null
#  status                  :string           default("generated"), not null
#  title                   :text             not null
#  vendor                  :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  gift_id                 :uuid
#  relationship_profile_id :uuid             not null
#  user_id                 :uuid             not null
#
# Indexes
#
#  index_gift_recommendations_on_gift_id                   (gift_id)
#  index_gift_recommendations_on_profile_status_generated  (relationship_profile_id,status,generated_at)
#  index_gift_recommendations_on_relationship_profile_id   (relationship_profile_id)
#  index_gift_recommendations_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (gift_id => gifts.id) ON DELETE => nullify
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class GiftRecommendation < ApplicationRecord
  MAX_TITLE_LENGTH = 200
  MAX_RATIONALE_LENGTH = 1_000
  MAX_VENDOR_LENGTH = 200
  MAX_OCCASION_LENGTH = 200
  MAX_NEEDED_BY = Date.new(9999, 12, 31)
  MAX_SOURCES = 8
  MAX_SOURCE_LABEL_LENGTH = 240
  STATUSES = %w[generated saved dismissed purchased].freeze
  LOCALES = %w[en es].freeze

  belongs_to :user
  belongs_to :relationship_profile
  belongs_to :gift, optional: true

  serialize :source_context, coder: JSON
  encrypts :title
  encrypts :rationale
  encrypts :source_context
  encrypts :vendor
  encrypts :occasion

  before_validation :normalize_text_fields

  validates :title, presence: true, length: { maximum: MAX_TITLE_LENGTH }
  validates :rationale, presence: true, length: { maximum: MAX_RATIONALE_LENGTH }
  validates :vendor, length: { maximum: MAX_VENDOR_LENGTH }, allow_blank: true
  validates :occasion, length: { maximum: MAX_OCCASION_LENGTH }, allow_blank: true
  validates :needed_by, comparison: { less_than_or_equal_to: MAX_NEEDED_BY }, allow_nil: true
  validates :estimated_price_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: Gift::MAX_PRICE_CENTS },
    allow_nil: true
  validates :budget_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: Gift::MAX_PRICE_CENTS },
    allow_nil: true
  validates :generated_at, presence: true
  validates :locale, inclusion: { in: LOCALES }
  validates :status, inclusion: { in: STATUSES }
  validate :relationship_profile_belongs_to_user
  validate :source_context_is_supported

  scope :visible, -> { where.not(status: "dismissed") }
  scope :recent_first, -> { order(generated_at: :desc, created_at: :desc, id: :desc) }

  STATUSES.each { |value| define_method("#{value}?") { status == value } }

  def source_ids
    source_context.filter_map { |source| source["id"] if source.is_a?(Hash) }
  end

  private

  def normalize_text_fields
    self.title = title.to_s.squish
    self.rationale = rationale.to_s.squish
    self.vendor = vendor.to_s.squish.presence
    self.occasion = occasion.to_s.squish.presence
  end

  def relationship_profile_belongs_to_user
    return if user.blank? || relationship_profile.blank?
    return if relationship_profile.user_id == user_id

    errors.add(:relationship_profile, :owner_mismatch)
  end

  def source_context_is_supported
    valid = source_context.is_a?(Array) &&
      source_context.present? &&
      source_context.length <= MAX_SOURCES &&
      source_context.all? { |source| valid_source?(source) }
    errors.add(:source_context, :invalid) unless valid
  end

  def valid_source?(source)
    source.is_a?(Hash) &&
      source["id"].is_a?(String) && source["id"].present? &&
      source["label"].is_a?(String) && source["label"].present? &&
      source["label"].length <= MAX_SOURCE_LABEL_LENGTH &&
      source["certainty"].in?(%w[confirmed inferred]) &&
      [ true, false ].include?(source["sensitive"])
  end
end
