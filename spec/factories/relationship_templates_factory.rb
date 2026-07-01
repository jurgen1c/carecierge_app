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
FactoryBot.define do
  factory :relationship_template do
    sequence(:key) { |index| "template_#{index}" }
    relationship_type { "RelationshipProfiles::Friend" }
    name { "Friend template" }
    description { "Default guidance for this relationship type." }
    active { true }
    system { true }
    position { 1 }
  end
end
