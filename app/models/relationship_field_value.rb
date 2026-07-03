# == Schema Information
#
# Table name: relationship_field_values
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  custom                  :boolean          default(FALSE), not null
#  hidden                  :boolean          default(FALSE), not null
#  key                     :string
#  label                   :string           not null
#  position                :integer          default(0), not null
#  value                   :text
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  template_field_id       :uuid
#
# Indexes
#
#  index_relationship_field_values_on_profile_and_lower_label     (relationship_profile_id, lower((label)::text)) UNIQUE WHERE (custom = true)
#  index_relationship_field_values_on_profile_and_template_field  (relationship_profile_id,template_field_id) UNIQUE WHERE (template_field_id IS NOT NULL)
#  index_relationship_field_values_on_profile_hidden_position     (relationship_profile_id,hidden,position)
#  index_relationship_field_values_on_relationship_profile_id     (relationship_profile_id)
#  index_relationship_field_values_on_template_field_id           (template_field_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#  fk_rails_...  (template_field_id => template_fields.id)
#
class RelationshipFieldValue < ApplicationRecord
  belongs_to :relationship_profile
  belongs_to :template_field, optional: true

  before_validation :apply_template_defaults
  before_validation :normalize_label
  before_validation :normalize_key

  validates :label, presence: true
  validates :label,
    uniqueness: {
      scope: :relationship_profile_id,
      case_sensitive: false,
      conditions: -> { where(custom: true) }
    },
    if: :custom?
  validates :value, presence: true, if: :value_required?
  validates :template_field_id, uniqueness: { scope: :relationship_profile_id, allow_nil: true }
  validate :template_field_exists, if: -> { template_field_id.present? }

  scope :custom, -> { where(custom: true) }
  scope :suggested, -> { where(custom: false) }
  scope :visible, -> { where(hidden: false) }
  scope :ordered, -> { order(:position, :label) }

  def display_label
    template_field&.localized_label || label
  end

  private

  def apply_template_defaults
    if template_field.present?
      self.key = template_field.key
      self.label = template_field.label
      self.custom = false
    elsif template_field_id.blank?
      self.custom = true
    end
  end

  def template_field_exists
    return if template_field.present?

    errors.add(:template_field, :unknown_template_field)
  end

  def normalize_label
    self.label = label.to_s.strip
  end

  def normalize_key
    self.key = key.to_s.strip.presence
  end

  def value_required?
    custom? || !hidden?
  end
end
