# == Schema Information
#
# Table name: privacy_vault_items
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  payload                 :text             not null
#  protectable_type        :string           not null
#  protected_at            :datetime         not null
#  suggestion_usage        :string           default("excluded"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  protectable_id          :uuid             not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_protected_at_06b534e13e  (relationship_profile_id,protected_at)
#  index_privacy_vault_items_on_protectable                (protectable_type,protectable_id) UNIQUE
#  index_privacy_vault_items_on_relationship_profile_id    (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
class PrivacyVaultItem < ApplicationRecord
  REDACTED_TEXT = "[vault protected]".freeze
  PROTECTABLE_TYPES = %w[MemoryRecord RelationshipFieldValue RelationshipNote].freeze
  SUGGESTION_USAGES = %w[excluded allowed].freeze

  belongs_to :relationship_profile
  belongs_to :protectable, polymorphic: true
  has_many :vault_access_events, dependent: :nullify

  serialize :payload, coder: JSON
  encrypts :payload

  validates :protectable_type, inclusion: { in: PROTECTABLE_TYPES }
  validates :payload, presence: true
  validates :suggestion_usage, inclusion: { in: SUGGESTION_USAGES }
  validates :protected_at, presence: true
  validates :protectable_id, uniqueness: { scope: :protectable_type }
  validate :protectable_belongs_to_relationship_profile
  validate :payload_has_display_content

  scope :ordered, -> { order(protected_at: :desc, created_at: :desc) }
  scope :suggestion_allowed, -> { where(suggestion_usage: "allowed") }

  def suggestion_allowed?
    suggestion_usage == "allowed"
  end

  def display_title
    return payload["title"] if payload["title"].present?
    return translated_template_field_title if payload["title_key"] == "relationship_template_field"

    I18n.t("privacy_vaults.item_types.#{payload.fetch('title_key')}")
  end

  def display_body
    payload.fetch("body")
  end

  def type_key
    return payload["title_key"].presence || "general_note" if protectable_type == "RelationshipNote"

    {
      "MemoryRecord" => "memory",
      "RelationshipFieldValue" => "relationship_detail"
    }.fetch(protectable_type)
  end

  private

  def protectable_belongs_to_relationship_profile
    return if protectable.blank?
    return if protectable.relationship_profile_id == relationship_profile_id

    errors.add(:protectable, :profile_mismatch)
  end

  def payload_has_display_content
    return if payload.is_a?(Hash) && payload_title_present? && payload["body"].is_a?(String)

    errors.add(:payload, :invalid)
  end

  def payload_title_present?
    payload["title"].present? || payload["title_key"].in?(%w[general_note private_note relationship_template_field])
  end

  def translated_template_field_title
    I18n.t(
      "relationship_templates.fields.#{payload.fetch('template_field_key')}.label",
      default: payload.fetch("title_default")
    )
  end
end
