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
