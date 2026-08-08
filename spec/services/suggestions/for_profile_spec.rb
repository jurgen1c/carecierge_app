require "rails_helper"

RSpec.describe Suggestions::ForProfile do
  it "builds every supported type from current source-backed relationship data" do
    now = Time.zone.local(2026, 8, 8, 9, 0)
    user = create(:user)
    profile = create(
      :relationship_profile,
      user:,
      type: "RelationshipProfiles::Colleague",
      preferred_name: "Maya",
      created_at: now - 30.days
    )
    create(
      :important_date,
      relationship_profile: profile,
      title: "Birthday",
      date_type: "birthday",
      starts_on: now.to_date + 12.days,
      recurrence: "none"
    )
    create(:desire, relationship_profile: profile, title: "Pottery tools", category: "gift")
    create(:desire, relationship_profile: profile, title: "Try a pottery class", category: "activity")
    create(:contact_cadence, relationship_profile: profile, interval_days: 7, created_at: now - 10.days)
    create(
      :relationship_preference,
      relationship_profile: profile,
      category: "communication",
      key: "Message style",
      value: "Short and sincere",
      confidence: "confirmed"
    )
    create(
      :mood_note,
      relationship_profile: profile,
      category: "distant",
      observation: "The last conversation felt distant.",
      observed_at: now - 2.days
    )
    create(
      :commitment,
      relationship_profile: profile,
      title: "Send the project notes",
      due_on: now.to_date - 1.day
    )

    suggestions = described_class.call(relationship_profile: profile, as_of: now)

    expect(suggestions.map(&:suggestion_type)).to contain_exactly(
      "gift",
      "message",
      "plan",
      "check_in",
      "event",
      "spontaneous",
      "repair_focused",
      "professional_follow_up"
    )
    expect(suggestions).to all(have_attributes(action_kind: "create_reminder"))
    expect(suggestions).to all(satisfy { |suggestion| suggestion.reasons.any? && suggestion.fingerprint.present? })
    expect(suggestions.select(&:high_impact?)).to all(be_high_impact_evidence_eligible)
  end

  it "preserves inferred persona evidence for low-impact suggestions" do
    profile = create(:relationship_profile, preferred_name: "Maya")
    memory = create(
      :memory_record,
      relationship_profile: profile,
      title: "Quiet check-ins",
      body: "Short messages may feel easier.",
      source: "ai_inferred",
      confidence: "medium"
    )

    suggestion = described_class.call(relationship_profile: profile).find { |item| item.suggestion_type == "message" }

    expect(suggestion).to be_present
    expect(suggestion).not_to be_high_impact
    expect(suggestion.reasons.sole).to have_attributes(source: memory, certainty: "inferred")
  end

  it "fails closed for archived profiles" do
    profile = create(:relationship_profile, discarded_at: Time.current)
    create(:memory_record, relationship_profile: profile)

    expect(described_class.call(relationship_profile: profile)).to be_empty
  end
end
