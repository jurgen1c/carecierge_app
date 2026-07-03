# == Schema Information
#
# Table name: template_fields
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  active                   :boolean          default(TRUE), not null
#  field_type               :string           default("text"), not null
#  key                      :string           not null
#  label                    :string           not null
#  position                 :integer          default(0), not null
#  prompt                   :text
#  required                 :boolean          default(FALSE), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  relationship_template_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_template_id_active_position_5de85f3010  (relationship_template_id,active,position)
#  index_template_fields_on_relationship_template_id           (relationship_template_id)
#  index_template_fields_on_relationship_template_id_and_key   (relationship_template_id,key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (relationship_template_id => relationship_templates.id)
#
require "rails_helper"

RSpec.describe TemplateField, type: :model do
  it { is_expected.to belong_to(:relationship_template) }
  it { is_expected.to have_many(:relationship_field_values) }
  it { is_expected.to validate_presence_of(:key) }
  it { is_expected.to validate_presence_of(:label) }

  it "prevents deletion while relationship field values reference it" do
    field = create(:template_field)
    value = create(:relationship_field_value, template_field: field)

    expect(field.destroy).to be(false)
    expect(field.errors[:base]).to be_present
    expect(value.reload.template_field).to eq(field)
  end
end
