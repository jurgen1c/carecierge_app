require "rails_helper"

RSpec.describe MessageDrafts::ContextBuilder do
  it "uses current non-protected relationship context and excludes private context by default" do
    profile = create(:relationship_profile, preferred_name: "Maya", pronouns: "she/her")
    create(:relationship_preference, relationship_profile: profile, key: "Message style", value: "Short and sincere")
    create(:important_date, relationship_profile: profile, title: "Birthday")
    create(:relationship_note, relationship_profile: profile, body: "Enjoys quiet garden walks.")
    create(:relationship_note, relationship_profile: profile, private: true, body: "Private family situation.")
    create(:memory_record, relationship_profile: profile, title: "Favorite drink", body: "Jasmine tea")
    create(:memory_record, relationship_profile: profile, status: "archived", title: "Old context", body: "Do not include this")
    create(:privacy_vault_item, relationship_profile: profile, payload: { "title" => "Vault", "body" => "Protected context" })

    result = described_class.new(relationship_profile: profile).call

    expect(result.text).to include("Maya", "she/her", "Short and sincere", "quiet garden walks", "Jasmine tea", "Birthday")
    expect(result.text).not_to include("Private family situation", "Protected context", "Do not include this")
    expect(result.categories).to include("profile", "preferences", "important_dates", "public_notes", "memories")
    expect(result.categories).not_to include("private_notes", "vault")
  end

  it "selects only the ten newest opted-in social-context notes" do
    profile = create(:relationship_profile)
    base_time = Time.zone.local(2026, 8, 13, 9)
    11.times do |index|
      create(
        :social_context_note,
        relationship_profile: profile,
        body: "Social context #{index}",
        allow_suggestions: true,
        created_at: base_time + index.minutes
      )
    end

    result = described_class.new(relationship_profile: profile).call

    expect(result.text).to include("Social context 10")
    expect(result.text).not_to include("Social context 0\n")
    expect(result.text.scan("User-provided social context").size).to eq(10)
  end

  it "includes visible relationship details while excluding hidden and vault-protected values" do
    profile = create(:relationship_profile)
    current_template = create(:relationship_template, relationship_type: profile.type)
    current_field = create(:template_field, relationship_template: current_template, label: "Current shared interest")
    prior_template = create(:relationship_template, relationship_type: "RelationshipProfiles::Spouse")
    prior_field = create(:template_field, relationship_template: prior_template, label: "Prior anniversary")
    create(
      :relationship_field_value,
      relationship_profile: profile,
      template_field: current_field,
      label: current_field.label,
      value: "Gardening"
    )
    create(
      :relationship_field_value,
      relationship_profile: profile,
      template_field: prior_field,
      label: prior_field.label,
      value: "June 1"
    )
    create(
      :relationship_field_value,
      relationship_profile: profile,
      template_field: nil,
      custom: true,
      label: "Preferred language",
      value: "Spanish"
    )
    create(
      :relationship_field_value,
      relationship_profile: profile,
      template_field: nil,
      custom: true,
      hidden: true,
      label: "Hidden workplace",
      value: "Do not include"
    )
    protected_detail = create(
      :relationship_field_value,
      relationship_profile: profile,
      template_field: nil,
      custom: true,
      label: "Private family context",
      value: "Keep this protected"
    )
    PrivacyVault::Protect.call(actor: profile.user, protectable: protected_detail)

    result = described_class.new(relationship_profile: profile).call

    expect(result.text).to include("Current shared interest: Gardening", "Preferred language: Spanish")
    expect(result.text).not_to include(
      "Prior anniversary",
      "June 1",
      "Hidden workplace",
      "Do not include",
      "Private family context",
      "Keep this protected"
    )
    expect(result.categories).to include("profile")
  end

  it "preserves uncertainty and source metadata for preferences and memories" do
    profile = create(:relationship_profile)
    create(
      :relationship_preference,
      relationship_profile: profile,
      key: "Message style",
      value: "Short and sincere",
      confidence: "inferred",
      source_notes: "Observed from recent conversations"
    )
    create(
      :memory_record,
      relationship_profile: profile,
      title: "Possible favorite tea",
      body: "Jasmine tea",
      source: "ai_inferred",
      confidence: "low"
    )

    result = described_class.new(relationship_profile: profile).call

    expect(result.text).to include(
      "Message style: [confidence: inferred; source: Observed from recent conversations] Short and sincere",
      "Possible favorite tea: [source: ai_inferred; confidence: low] Jasmine tea"
    )
  end

  it "retains uncertainty metadata when a source value is truncated" do
    profile = create(:relationship_profile)
    create(
      :relationship_preference,
      relationship_profile: profile,
      key: "Long inferred preference",
      value: "A" * 2_000,
      confidence: "inferred"
    )

    result = described_class.new(relationship_profile: profile).call

    expect(result.text).to include("Long inferred preference: [confidence: inferred]")
    expect(result.text.length).to be <= described_class::MAX_CHARACTERS
  end

  it "reserves room for uncertainty metadata when preference and memory labels are long" do
    profile = create(:relationship_profile)
    create(
      :relationship_preference,
      relationship_profile: profile,
      key: "Preference " + ("P" * 990),
      value: "Short and sincere",
      confidence: "inferred",
      source_notes: "Observed from recent conversations"
    )
    create(
      :memory_record,
      relationship_profile: profile,
      title: "Memory " + ("M" * 990),
      body: "Jasmine tea",
      source: "ai_inferred",
      confidence: "low"
    )

    result = described_class.new(relationship_profile: profile).call

    expect(result.text).to include(
      "[confidence: inferred; source: Observed from recent conversations] Short and sincere",
      "[source: ai_inferred; confidence: low] Jasmine tea"
    )
    expect(result.text.lines.map { |line| line.chomp.length }.max).to be <= described_class::MAX_ENTRY_CHARACTERS
  end

  it "caps complete entries so a long label cannot displace later context" do
    profile = create(:relationship_profile)
    create(:important_date, relationship_profile: profile, title: "X" * 7_000)
    create(
      :relationship_preference,
      relationship_profile: profile,
      key: "Message style",
      value: "Short and sincere"
    )

    result = described_class.new(relationship_profile: profile).call

    expect(result.text.lines.map { |line| line.chomp.length }.max).to be <= described_class::MAX_ENTRY_CHARACTERS
    expect(result.text).to include("Message style", "Short and sincere")
  end

  it "adds private notes and vault payloads only when each source is explicitly allowed" do
    profile = create(:relationship_profile)
    create(:relationship_note, relationship_profile: profile, private: true, body: "Prefers a gentle opening.")
    create(:privacy_vault_item, relationship_profile: profile, payload: { "title" => "Protected boundary", "body" => "Avoid discussing work." })

    result = described_class.new(
      relationship_profile: profile,
      include_private_notes: true,
      include_vault_context: true
    ).call

    expect(result.text).to include("Prefers a gentle opening", "Protected boundary", "Avoid discussing work")
    expect(result.categories).to include("private_notes", "vault")
  end

  it "reserves context for each explicitly allowed sensitive source" do
    profile = create(:relationship_profile)
    create(:relationship_preference, relationship_profile: profile, key: "Long preference", value: "A" * 7_000)
    create(:relationship_note, relationship_profile: profile, private: true, body: "Private family boundary.")
    create(:privacy_vault_item, relationship_profile: profile, payload: { "title" => "Protected boundary", "body" => "Avoid discussing work." })

    result = described_class.new(
      relationship_profile: profile,
      include_private_notes: true,
      include_vault_context: true
    ).call

    expect(result.text).to include("Private family boundary", "Protected boundary", "Avoid discussing work")
    expect(result.categories).to include("private_notes", "vault")
    expect(result.text.length).to be <= described_class::MAX_CHARACTERS
  end

  it "applies the memory limit after excluding date-stale records" do
    profile = create(:relationship_profile)

    Timecop.freeze(Time.zone.local(2026, 8, 11, 12)) do
      create_list(:memory_record, 10, relationship_profile: profile, stale_after: Date.new(2026, 8, 10))
      create(:memory_record, relationship_profile: profile, title: "Current memory", body: "Still useful", stale_after: Date.new(2026, 8, 11))

      result = described_class.new(relationship_profile: profile).call

      expect(result.text).to include("Current memory", "Still useful")
      expect(result.categories).to include("memories")
    end
  end

  it "bounds the context sent to the provider" do
    profile = create(:relationship_profile)
    create(:relationship_note, relationship_profile: profile, body: "A" * 10_000)

    result = described_class.new(relationship_profile: profile).call

    expect(result.text.length).to be <= described_class::MAX_CHARACTERS
  end

  it "includes only explicitly enabled social context and excludes draft interpretations" do
    profile = create(:relationship_profile)
    create(:social_context_note, relationship_profile: profile, body: "Do not include this social note.")
    create(
      :social_context_note,
      relationship_profile: profile,
      body: "Maya posted about a bookstore event.",
      allow_suggestions: true,
      interpretation: "This may be a comfortable message topic.",
      interpretation_status: "draft",
      suggested_uses: %w[message]
    )
    approved = create(
      :social_context_note,
      relationship_profile: profile,
      body: "Maya shared a neighborhood gathering.",
      allow_suggestions: true,
      interpretation: "A low-pressure check-in may fit.",
      interpretation_status: "approved",
      suggested_uses: %w[message]
    )

    result = described_class.new(relationship_profile: profile).call

    expect(result.text).to include(
      "Maya posted about a bookstore event",
      "Maya shared a neighborhood gathering",
      "[source: ai_inferred; review_status: approved] A low-pressure check-in may fit"
    )
    expect(result.text).to include("[source: user_provided] Maya shared a neighborhood gathering")
    expect(result.text).not_to include("Do not include this social note", "comfortable message topic")
    expect(result.categories).to include("social_context")
    expect(approved.downstream_context).to include("low-pressure check-in")
  end

  it "excludes an approved AI interpretation when message drafting was not selected" do
    profile = create(:relationship_profile)
    create(
      :social_context_note,
      relationship_profile: profile,
      body: "Maya shared a neighborhood gathering.",
      allow_suggestions: true,
      interpretation: "A gift may be timely.",
      interpretation_status: "approved",
      suggested_uses: %w[gift]
    )

    result = described_class.new(relationship_profile: profile).call

    expect(result.text).to include("[source: user_provided] Maya shared a neighborhood gathering")
    expect(result.text).not_to include("A gift may be timely")
  end
end
