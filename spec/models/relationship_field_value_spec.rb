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
require "rails_helper"

RSpec.describe RelationshipFieldValue, type: :model do
  it { is_expected.to belong_to(:relationship_profile) }
  it { is_expected.to belong_to(:template_field).optional }
  it { is_expected.to validate_presence_of(:label) }

  it "allows a hidden suggested field without a value" do
    value = build(:relationship_field_value, value: nil, hidden: true)

    expect(value).to be_valid
  end

  it "requires visible fields to include a value" do
    value = build(:relationship_field_value, value: nil, hidden: false)

    expect(value).not_to be_valid
    expect(value.errors[:value]).to include("can't be blank")
  end

  it "validates an unknown template field id before database constraints" do
    value = build(:relationship_field_value, template_field_id: SecureRandom.uuid, template_field: nil)

    expect(value).not_to be_valid
    expect(value.errors[:template_field]).to include("is not a valid suggested field")
  end

  it "validates duplicate custom labels case-insensitively before database constraints" do
    profile = create(:relationship_profile)
    create(:relationship_field_value, relationship_profile: profile, template_field: nil, label: "Favorite snack", custom: true)
    duplicate = build(:relationship_field_value, relationship_profile: profile, template_field: nil, label: " favorite snack ", custom: true)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:label]).to include("has already been taken")
  end

  it "persists canonical template labels independent of the current locale" do
    field = create(:template_field, key: "communication_style", label: "Communication style")
    value = build(:relationship_field_value, template_field: field)

    I18n.with_locale(:es) do
      value.valid?
      expect(value.display_label).to eq("Estilo de comunicación")
    end

    expect(value.label).to eq("Communication style")
  end
end
