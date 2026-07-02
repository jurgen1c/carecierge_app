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
FactoryBot.define do
  factory :relationship_field_value do
    relationship_profile
    template_field
    label { template_field&.label || "Favorite snacks" }
    value { "Mango" }
    hidden { false }
    custom { template_field.blank? }
    position { 1 }
  end
end
