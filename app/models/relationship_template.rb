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
class RelationshipTemplate < ApplicationRecord
  DEFAULT_DEFINITIONS = {
    "RelationshipProfiles::Spouse" => {
      key: "spouse",
      name: "Spouse",
      description: "Default reminders and care context for a spouse.",
      fields: [
        { key: "anniversary", label: "Anniversary", prompt: "Important anniversaries or shared dates" },
        { key: "date_ideas", label: "Date ideas", prompt: "Ideas that would feel thoughtful" },
        { key: "love_language", label: "Love language", prompt: "Ways they most appreciate care" },
        { key: "favorite_restaurants", label: "Favorite restaurants", prompt: "Places they like or want to try" },
        { key: "emotional_triggers", label: "Emotional triggers", prompt: "Sensitive topics or situations to handle carefully" },
        { key: "gift_preferences", label: "Gift preferences", prompt: "Useful gift ideas and preferences" }
      ]
    },
    "RelationshipProfiles::Boss" => {
      key: "boss",
      name: "Boss",
      description: "Default work-context fields for a manager or boss.",
      fields: [
        { key: "communication_style", label: "Communication style", prompt: "How they prefer updates or questions" },
        { key: "current_priorities", label: "Current priorities", prompt: "Work that matters most right now" },
        { key: "reporting_preferences", label: "Reporting preferences", prompt: "How to share status or outcomes" },
        { key: "meeting_style", label: "Meeting style", prompt: "Useful meeting preferences and norms" },
        { key: "feedback_preferences", label: "Feedback preferences", prompt: "How they tend to give or receive feedback" }
      ]
    },
    "RelationshipProfiles::Child" => {
      key: "child",
      name: "Child",
      description: "Default care-context fields for a child.",
      fields: [
        { key: "school_events", label: "School events", prompt: "Upcoming school moments to remember" },
        { key: "favorite_activities", label: "Favorite activities", prompt: "Activities they enjoy most" },
        { key: "clothing_size", label: "Clothing size", prompt: "Current sizes or fit notes" },
        { key: "food_preferences", label: "Food preferences", prompt: "Foods they like or avoid" },
        { key: "allergies", label: "Allergies", prompt: "Allergies or sensitivities to keep visible" },
        { key: "milestones", label: "Milestones", prompt: "Recent or upcoming milestones" }
      ]
    }
  }.freeze

  has_many :template_fields, -> { ordered }, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :relationship_type, presence: true, uniqueness: true, inclusion: { in: RelationshipProfile::TYPE_LABELS.keys }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def self.default_definitions
    DEFAULT_DEFINITIONS
  end

  def self.for_relationship_type(relationship_type)
    active.includes(:template_fields).find_by(relationship_type:)
  end

  def localized_description
    I18n.t("relationship_templates.descriptions.#{key}", default: description)
  end

  def self.install_defaults!
    transaction do
      DEFAULT_DEFINITIONS.each_with_index do |(relationship_type, definition), template_position|
        template = find_by(relationship_type:) || find_or_initialize_by(key: definition[:key])
        next if template.persisted? && !template.system?

        template.assign_attributes(
          relationship_type:,
          name: definition[:name],
          description: definition[:description],
          active: true,
          system: true,
          position: template_position
        )
        template.save!

        definition[:fields].each_with_index do |field_definition, field_position|
          field = template.template_fields.find_or_initialize_by(key: field_definition[:key])
          field.assign_attributes(
            label: field_definition[:label],
            prompt: field_definition[:prompt],
            field_type: "text",
            required: false,
            active: true,
            position: field_position
          )
          field.save!
        end
      end
    end
  end
end
