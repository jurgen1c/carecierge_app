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
require "rails_helper"

RSpec.describe RelationshipPreference, type: :model do
  subject(:preference) { build(:relationship_preference) }

  it { is_expected.to belong_to(:relationship_profile) }
  it { is_expected.to define_enum_for(:preference_type).with_values(positive: "positive", negative: "negative", neutral: "neutral", constraint: "constraint").backed_by_column_of_type(:string) }
  it { is_expected.to define_enum_for(:category).with_values(general: "general", food: "food", gifts: "gifts", communication: "communication", social_settings: "social_settings", boundaries: "boundaries", allergies: "allergies", cultural_constraints: "cultural_constraints").backed_by_column_of_type(:string) }
  it { is_expected.to define_enum_for(:confidence).with_values(confirmed: "confirmed", high: "high", medium: "medium", low: "low", inferred: "inferred").backed_by_column_of_type(:string) }
  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_presence_of(:value) }
  it { is_expected.to validate_presence_of(:preference_type) }
  it { is_expected.to validate_presence_of(:category) }
  it { is_expected.to validate_presence_of(:confidence) }

  it "allows one preference key per relationship profile case-insensitively" do
    profile = create(:relationship_profile)
    create(:relationship_preference, relationship_profile: profile, key: "Coffee", value: "decaf")
    duplicate = build(:relationship_preference, relationship_profile: profile, key: "coffee", value: "tea")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors).to be_added(:key, :taken, value: "coffee")
  end

  it "normalizes searchable text fields while preserving optional notes" do
    preference = described_class.new(
      key: "  Dinner setting ",
      value: " quiet restaurants ",
      source_notes: " Mentioned after a crowded team dinner. "
    )

    preference.valid?

    expect(preference.key).to eq("Dinner setting")
    expect(preference.value).to eq("quiet restaurants")
    expect(preference.source_notes).to eq("Mentioned after a crowded team dinner.")
  end

  it "localizes enum labels" do
    preference = build(:relationship_preference, preference_type: "constraint", category: "cultural_constraints", confidence: "confirmed")

    I18n.with_locale(:es) do
      expect(preference.preference_type_label).to eq("Restricción")
      expect(preference.category_label).to eq("Restricciones culturales")
      expect(preference.confidence_label).to eq("Confirmada")
    end
  end

  it "defaults legacy-compatible metadata to neutral general inferred values" do
    preference = described_class.new(key: "Topics", value: "books")

    expect(preference.preference_type).to eq("neutral")
    expect(preference.category).to eq("general")
    expect(preference.confidence).to eq("inferred")
  end
end
