class RelationshipProfiles::FormState
  CONTACT_KINDS = %w[email personal_phone business_phone].freeze
  SLOT_COUNT = 3

  attr_reader :relationship_profile

  def initialize(relationship_profile)
    @relationship_profile = relationship_profile
  end

  def prepare!
    CONTACT_KINDS.each { |kind| contact_method_for(kind) }
    public_note
    private_note
    preference_slots
    tag_slots
    relationship_template_groups
    custom_field_value_slots
    self
  end

  def contact_method_for(kind)
    relationship_profile.contact_methods.detect { |method| method.kind == kind } ||
      relationship_profile.contact_methods.build(kind:)
  end

  def public_note
    relationship_profile.relationship_notes.detect { |note| !note.private? } ||
      relationship_profile.relationship_notes.build(private: false, category: "General")
  end

  def private_note
    relationship_profile.relationship_notes.detect(&:private?) ||
      relationship_profile.relationship_notes.build(private: true, category: "Private")
  end

  def preference_slots
    fill_slots(relationship_profile.relationship_preferences.to_a) do
      relationship_profile.relationship_preferences.build
    end
  end

  def tag_slots
    fill_slots(relationship_profile.relationship_tags.to_a) do
      relationship_profile.relationship_tags.build
    end
  end

  def relationship_template
    RelationshipTemplate.for_relationship_type(relationship_profile.type.presence || RelationshipProfile::DEFAULT_TYPE)
  end

  def relationship_template_groups
    @relationship_template_groups ||= RelationshipTemplate.active.ordered.includes(:template_fields).map do |template|
      [ template, active_template_fields_for(template).map { |field| template_field_value_for(field) } ]
    end
  end

  def template_field_value_for(template_field)
    relationship_profile.relationship_field_values.detect { |field_value| field_value.template_field_id == template_field.id } ||
      relationship_profile.relationship_field_values.build(
        template_field:,
        key: template_field.key,
        label: template_field.label,
        custom: false,
        position: template_field.position
      )
  end

  def custom_field_value_slots
    custom_values = relationship_profile.relationship_field_values.select { |field_value| field_value.template_field_id.blank? }

    fill_slots(custom_values) { relationship_profile.relationship_field_values.build(custom: true) }
  end

  private

  def active_template_fields_for(template)
    template.template_fields.select(&:active?).sort_by { |field| [ field.position, field.label ] }
  end

  def fill_slots(records)
    records.tap do |slots|
      (SLOT_COUNT - slots.size).times { slots << yield }
    end
  end
end
