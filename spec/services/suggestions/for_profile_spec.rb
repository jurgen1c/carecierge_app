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

  it "reuses important dates preloaded on the relationship profile" do
    now = Time.zone.local(2026, 8, 8, 9, 0)
    profile = create(:relationship_profile, preferred_name: "Maya")
    important_date = create(
      :important_date,
      relationship_profile: profile,
      title: "Birthday",
      starts_on: now.to_date + 12.days,
      recurrence: "none"
    )
    preloaded_dates = profile.important_dates.reload.to_a
    expect(ImportantDate).not_to receive(:where)

    suggestion = described_class.call(
      relationship_profile: profile,
      as_of: now,
      important_dates: preloaded_dates
    )
      .find { |item| item.suggestion_type == "event" }

    expect(suggestion.reasons.sole.source).to eq(important_date)
  end

  it "fails closed for archived profiles" do
    profile = create(:relationship_profile, discarded_at: Time.current)
    create(:memory_record, relationship_profile: profile)

    expect(described_class.call(relationship_profile: profile)).to be_empty
  end

  it "derives low-impact reminder, gift, message, and conversation suggestions from reviewed opted-in social context" do
    profile = create(:relationship_profile, preferred_name: "Maya")
    note = create(
      :social_context_note,
      relationship_profile: profile,
      body: "Maya shared a bookstore event and a new hiking interest.",
      allow_suggestions: true,
      interpretation: "A bookstore visit or hiking conversation may feel timely.",
      interpretation_status: "approved",
      suggested_uses: %w[gift message conversation_topic reminder]
    )

    suggestions = described_class.call(relationship_profile: profile)
    social_suggestions = suggestions.select { |suggestion| suggestion.reasons.any? { |reason| reason.source == note } }

    expect(social_suggestions.map(&:suggestion_type)).to contain_exactly(
      "gift",
      "message",
      "conversation_topic",
      "social_reminder"
    )
    expect(social_suggestions).to all(satisfy { |suggestion| suggestion.reasons.sole.certainty == "inferred" })
    expect(social_suggestions).to all(satisfy { |suggestion| suggestion.action_kind == "create_reminder" })
  end

  it "does not derive suggestions from disabled or unreviewed social context" do
    profile = create(:relationship_profile)
    create(
      :social_context_note,
      relationship_profile: profile,
      allow_suggestions: false,
      interpretation: "Could support a gift.",
      interpretation_status: "approved",
      suggested_uses: %w[gift]
    )
    create(
      :social_context_note,
      relationship_profile: profile,
      allow_suggestions: true,
      interpretation: "Could support a conversation.",
      interpretation_status: "draft",
      suggested_uses: %w[conversation_topic]
    )

    suggestions = described_class.call(relationship_profile: profile)

    expect(suggestions.flat_map(&:reasons).map(&:source)).to all(satisfy { |source| !source.is_a?(SocialContextNote) })
  end

  it "reuses a supplied social context collection" do
    profile = create(:relationship_profile)
    note = create(
      :social_context_note,
      relationship_profile: profile,
      allow_suggestions: true,
      interpretation: "A conversation may be timely.",
      interpretation_status: "approved",
      suggested_uses: %w[conversation_topic]
    )

    expect(profile).not_to receive(:social_context_notes)

    suggestions = described_class.call(relationship_profile: profile, social_context_notes: [ note ])

    expect(suggestions.find { |item| item.suggestion_type == "conversation_topic" }).to be_present
  end

  it "bounds fallback social-context sources to the ten newest opted-in notes" do
    profile = create(:relationship_profile)
    base_time = Time.zone.local(2026, 8, 13, 9)
    notes = 11.times.map do |index|
      create(
        :social_context_note,
        relationship_profile: profile,
        body: "Social context #{index}",
        allow_suggestions: true,
        interpretation: "Conversation context #{index}",
        interpretation_status: "approved",
        suggested_uses: %w[conversation_topic],
        created_at: base_time + index.minutes
      )
    end
    sql = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      sql << payload[:sql] unless payload[:name] == "SCHEMA"
    end

    suggestions = ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      described_class.call(relationship_profile: profile)
    end

    social_context_query = sql.find { |statement| statement.include?('FROM "social_context_notes"') }
    expect(social_context_query).to include("LIMIT")
    expect(suggestions.find { |item| item.suggestion_type == "conversation_topic" }.reasons.sole.source).to eq(notes.last)
  end
end
