# == Schema Information
#
# Table name: relationship_templates
# Database name: primary
#
#  id                :uuid             not null, primary key
#  active            :boolean          default(TRUE), not null
#  description       :text
#  key               :string           not null
#  name              :string           not null
#  position          :integer          default(0), not null
#  relationship_type :string           not null
#  system            :boolean          default(TRUE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_relationship_templates_on_active_and_position  (active,position)
#  index_relationship_templates_on_key                  (key) UNIQUE
#  index_relationship_templates_on_relationship_type    (relationship_type) UNIQUE
#
require "rails_helper"

RSpec.describe RelationshipTemplate, type: :model do
  it { is_expected.to have_many(:template_fields).dependent(:destroy) }
  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:relationship_type) }

  it "defines default templates for common relationship types" do
    expect(described_class.default_definitions.keys).to include(
      "RelationshipProfiles::Spouse",
      "RelationshipProfiles::Boss",
      "RelationshipProfiles::Child"
    )
  end

  it "installs default templates and fields idempotently" do
    expect do
      described_class.install_defaults!
      described_class.install_defaults!
    end.to change(described_class, :count).by(described_class.default_definitions.size)

    boss_template = described_class.find_by!(relationship_type: "RelationshipProfiles::Boss")

    expect(boss_template.template_fields.pluck(:key)).to include("communication_style", "current_priorities")
  end

  it "skips non-system templates that already own a default relationship type" do
    template = create(
      :relationship_template,
      key: "admin_boss",
      relationship_type: "RelationshipProfiles::Boss",
      name: "Admin configured boss",
      system: false
    )

    expect do
      described_class.install_defaults!
    end.to change(described_class, :count).by(described_class.default_definitions.size - 1)

    expect(template.reload).to have_attributes(
      key: "admin_boss",
      name: "Admin configured boss",
      system: false
    )
    expect(template.template_fields).to be_empty
  end

  it "localizes default template descriptions" do
    template = build(:relationship_template, key: "child", description: "Default care-context fields for a child.")

    I18n.with_locale(:es) do
      expect(template.localized_description).to eq("Campos de contexto de cuidado predeterminados para un hijo o hija.")
    end
  end
end
