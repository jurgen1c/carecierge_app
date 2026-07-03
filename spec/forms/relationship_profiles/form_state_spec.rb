require "rails_helper"

RSpec.describe RelationshipProfiles::FormState do
  subject(:form_state) { described_class.new(profile) }

  let(:profile) { build(:relationship_profile, type: "RelationshipProfiles::Boss") }

  it "matches template suggestions to the selected relationship type" do
    template = create(:relationship_template, relationship_type: "RelationshipProfiles::Boss")
    field = create(:template_field, relationship_template: template, key: "communication_style")

    expect(form_state.relationship_template).to eq(template)
    expect(form_state.template_field_value_for(field).template_field).to eq(field)
  end

  it "prepares suggested field values with canonical labels for persistence" do
    template = create(:relationship_template, relationship_type: "RelationshipProfiles::Boss")
    field = create(:template_field, relationship_template: template, key: "communication_style", label: "Communication style")

    I18n.with_locale(:es) do
      field_value = form_state.template_field_value_for(field)

      expect(field_value.label).to eq("Communication style")
      expect(field_value.display_label).to eq("Estilo de comunicación")
    end
  end

  it "prepares template field values and custom field slots for forms" do
    template = create(:relationship_template, relationship_type: "RelationshipProfiles::Boss")
    field = create(:template_field, relationship_template: template, key: "school_events")

    form_state.prepare!

    expect(profile.relationship_field_values.map(&:template_field)).to include(field)
    expect(form_state.custom_field_value_slots.size).to eq(described_class::SLOT_COUNT)
  end

  it "orders existing custom field slots deterministically and preserves stored positions" do
    later_value = profile.relationship_field_values.build(template_field: nil, label: "Zoo notes", value: "late", custom: true, position: 200)
    earlier_value = profile.relationship_field_values.build(template_field: nil, label: "Allergy notes", value: "early", custom: true, position: 100)

    slots = form_state.custom_field_value_slots

    expect(slots.first(2)).to eq([ earlier_value, later_value ])
    expect(slots.map(&:position)).to eq([ 100, 200, 201 ])
  end

  it "centralizes the active relationship template fallback type" do
    create(:relationship_template, relationship_type: "RelationshipProfiles::Spouse", position: 0)
    create(:relationship_template, relationship_type: RelationshipProfile::DEFAULT_TYPE, position: 1)
    profile.type = "RelationshipProfiles::Neighbor"

    expect(form_state.fallback_relationship_template_type).to eq(RelationshipProfile::DEFAULT_TYPE)
    expect(form_state.active_relationship_template_type).to eq(RelationshipProfile::DEFAULT_TYPE)
  end

  it "uses preloaded template fields when building template groups" do
    boss_template = create(:relationship_template, relationship_type: "RelationshipProfiles::Boss", position: 1)
    create(:template_field, relationship_template: boss_template, key: "inactive_field", label: "Inactive field", active: false, position: 1)
    later_field = create(:template_field, relationship_template: boss_template, key: "later_field", label: "Later field", position: 2)
    first_field = create(:template_field, relationship_template: boss_template, key: "first_field", label: "First field", position: 1)
    child_template = create(:relationship_template, relationship_type: "RelationshipProfiles::Child", position: 2)
    create(:template_field, relationship_template: child_template, key: "child_field", label: "Child field", position: 1)

    sql = capture_sql { form_state.relationship_template_groups }
    field_queries = sql.grep(/FROM "template_fields"/)
    boss_group = form_state.relationship_template_groups.detect { |template, _field_values| template == boss_template }

    expect(field_queries.size).to eq(1)
    expect(boss_group.last.map(&:template_field)).to eq([ first_field, later_field ])
  end

  it "memoizes template groups for the form render lifecycle" do
    create(:template_field)

    first_groups = nil
    second_groups = nil

    sql = capture_sql do
      first_groups = form_state.relationship_template_groups
      second_groups = form_state.relationship_template_groups
    end

    expect(second_groups).to equal(first_groups)
    expect(sql.grep(/FROM "relationship_templates"/).size).to eq(1)
    expect(sql.grep(/FROM "template_fields"/).size).to eq(1)
  end

  it "prepares contact, note, preference, and tag slots for forms" do
    form_state.prepare!

    expect(form_state.contact_method_for("email").kind).to eq("email")
    expect(form_state.public_note).not_to be_private
    expect(form_state.private_note).to be_private
    expect(form_state.preference_slots.size).to eq(described_class::SLOT_COUNT)
    expect(form_state.tag_slots.size).to eq(described_class::SLOT_COUNT)
  end

  def capture_sql
    queries = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:cached] || payload[:name] == "SCHEMA"

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }

    queries
  end
end
