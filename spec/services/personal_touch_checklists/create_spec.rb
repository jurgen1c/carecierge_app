require "rails_helper"

RSpec.describe PersonalTouchChecklists::Create do
  it "creates one idempotent checklist with practical prompts and source-backed preferences" do
    profile = create(:relationship_profile)
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)
    preference = create(
      :relationship_preference,
      relationship_profile: profile,
      category: "allergies",
      preference_type: "constraint",
      key: "Tree nuts",
      value: "Avoid entirely",
      confidence: "confirmed"
    )

    checklist = described_class.call(actor: profile.user, moment: plan, locale: :en)
    repeated = described_class.call(actor: profile.user, moment: plan, locale: :en)

    expect(repeated).to eq(checklist)
    expect(plan.reload.personal_touch_checklist).to eq(checklist)
    expect(checklist.personal_touch_items.suggested.pluck(:title)).to include(
      "Write a short personal note",
      "Plan around Tree nuts: Avoid entirely"
    )

    sourced = checklist.personal_touch_items.find { |item| item.title == "Plan around Tree nuts: Avoid entirely" }
    expect(sourced).to have_attributes(category: "dietary_need", origin: "suggested")
    expect(sourced.source_context).to eq([
      {
        "source_type" => "RelationshipPreference",
        "source_id" => preference.id,
        "source_label" => "Tree nuts",
        "certainty" => "confirmed"
      }
    ])
    event = AuditEvent.find_by!(action: "personal_touch_checklist.created")
    expect(event).to have_attributes(
      user: profile.user,
      target_type: "RelationshipProfile",
      target_id: profile.id,
      metadata: { "count" => checklist.personal_touch_items.length }
    )
    expect(AuditEvent.where(action: "personal_touch_checklist.created").count).to eq(1)
  end

  it "normalizes non-confirmed preference confidence to inferred certainty" do
    profile = create(:relationship_profile)
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)
    preference = create(
      :relationship_preference,
      relationship_profile: profile,
      confidence: "high"
    )

    checklist = described_class.call(actor: profile.user, moment: plan, locale: :en)
    source = checklist.personal_touch_items.filter_map do |item|
      item.source_context.find { |context| context["source_id"] == preference.id }
    end.sole

    expect(source.fetch("certainty")).to eq("inferred")
  end

  it "rejects a cross-owner moment" do
    plan = create(:event_plan)

    expect do
      described_class.call(actor: create(:user), moment: plan)
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "prioritizes safety-sensitive preference categories before applying the suggestion cap" do
    profile = create(:relationship_profile)
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)
    base_time = Time.zone.local(2026, 8, 22, 10)

    6.times do |index|
      create(
        :relationship_preference,
        relationship_profile: profile,
        key: "Ordinary preference #{index}",
        value: "Ordinary value #{index}",
        created_at: base_time + index.minutes
      )
    end
    allergy = create(
      :relationship_preference,
      relationship_profile: profile,
      category: "allergies",
      preference_type: "neutral",
      key: "Shellfish",
      value: "Avoid entirely",
      created_at: base_time + 1.hour
    )

    checklist = described_class.call(actor: profile.user, moment: plan, locale: :en)
    sourced_preference_ids = checklist.personal_touch_items.suggested.flat_map do |item|
      item.source_context.map { |source| source.fetch("source_id") }
    end

    expect(sourced_preference_ids).to include(allergy.id)
    expect(sourced_preference_ids.length).to eq(described_class::MAX_PREFERENCE_SUGGESTIONS)
  end

  it "bounds generated preference titles to the persisted item limit" do
    profile = create(:relationship_profile)
    plan = create(:event_plan, user: profile.user, relationship_profile: profile)
    preference = create(
      :relationship_preference,
      relationship_profile: profile,
      key: "K" * 255,
      value: "V" * 255
    )

    checklist = described_class.call(actor: profile.user, moment: plan, locale: :en)
    sourced_item = checklist.personal_touch_items.suggested.find do |item|
      item.source_context.any? { |source| source.fetch("source_id") == preference.id }
    end

    expect(sourced_item.title.length).to eq(PersonalTouchItem::MAX_TITLE_LENGTH)
    expect(sourced_item.source_context.sole.fetch("source_label").length).to eq(
      PersonalTouchItem::MAX_SOURCE_LABEL_LENGTH
    )
  end

  it "refuses an archived relationship after acquiring its lock" do
    plan = create(:event_plan)
    plan.relationship_profile.archive!

    expect do
      described_class.call(actor: plan.user, moment: plan)
    end.to raise_error(ActiveRecord::RecordNotFound)
  end
end
