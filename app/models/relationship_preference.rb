# == Schema Information
#
# Table name: relationship_preferences
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  category                :string           default("general"), not null
#  confidence              :string           default("inferred"), not null
#  key                     :string           not null
#  learned_on              :date
#  preference_type         :string           default("neutral"), not null
#  source_notes            :text
#  value                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_category_de91ce2a16         (relationship_profile_id,category)
#  idx_on_relationship_profile_id_confidence_1dd4e61f57       (relationship_profile_id,confidence)
#  idx_on_relationship_profile_id_preference_type_3701ad82f6  (relationship_profile_id,preference_type)
#  idx_relationship_preferences_on_profile_and_lower_key      (relationship_profile_id, lower((key)::text)) UNIQUE
#  index_relationship_preferences_on_relationship_profile_id  (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
class RelationshipPreference < ApplicationRecord
  enum :preference_type, {
    positive: "positive",
    negative: "negative",
    neutral: "neutral",
    constraint: "constraint"
  }

  enum :category, {
    general: "general",
    food: "food",
    gifts: "gifts",
    communication: "communication",
    social_settings: "social_settings",
    boundaries: "boundaries",
    allergies: "allergies",
    cultural_constraints: "cultural_constraints"
  }

  enum :confidence, {
    confirmed: "confirmed",
    high: "high",
    medium: "medium",
    low: "low",
    inferred: "inferred"
  }

  belongs_to :relationship_profile

  before_validation :normalize_text_fields

  validates :preference_type, presence: true
  validates :category, presence: true
  validates :confidence, presence: true
  validates :key, presence: true, uniqueness: { scope: :relationship_profile_id, case_sensitive: false }
  validates :value, presence: true

  def preference_type_label
    self.class.preference_type_label(preference_type)
  end

  def category_label
    self.class.category_label(category)
  end

  def confidence_label
    self.class.confidence_label(confidence)
  end

  def self.preference_type_options
    preference_types.keys.map { |value| [ preference_type_label(value), value ] }
  end

  def self.category_options
    categories.keys.map { |value| [ category_label(value), value ] }
  end

  def self.confidence_options
    confidences.keys.map { |value| [ confidence_label(value), value ] }
  end

  def self.preference_type_label(value)
    I18n.t("relationship_preferences.preference_types.#{value}")
  end

  def self.category_label(value)
    I18n.t("relationship_preferences.categories.#{value}")
  end

  def self.confidence_label(value)
    I18n.t("relationship_preferences.confidences.#{value}")
  end

  private

  def normalize_text_fields
    self.key = key.to_s.strip
    self.value = value.to_s.strip
    self.source_notes = source_notes.to_s.strip.presence
  end
end
