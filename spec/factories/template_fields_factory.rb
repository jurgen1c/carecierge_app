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
FactoryBot.define do
  factory :template_field do
    relationship_template
    sequence(:key) { |index| "field_#{index}" }
    label { "Favorite snacks" }
    prompt { "What should you remember?" }
    field_type { "text" }
    required { false }
    active { true }
    position { 1 }
  end
end
