require "rails_helper"

RSpec.describe RelationshipBriefings::ContextBuilder do
  it "builds a bounded, source-backed catalog with explicit certainty" do
    profile = create(:relationship_profile, preferred_name: "Maya")
    timeline = create(
      :timeline_entry,
      relationship_profile: profile,
      title: "Started a new role",
      occurred_at: Time.zone.local(2026, 8, 14, 10)
    )
    commitment = create(:commitment, relationship_profile: profile, title: "Send the portfolio", status: "open")
    important_date = create(
      :important_date,
      relationship_profile: profile,
      date_type: "custom",
      title: "Project launch",
      starts_on: Date.new(2026, 8, 20),
      recurrence: "none"
    )
    confirmed = create(
      :relationship_preference,
      relationship_profile: profile,
      key: "Check-ins",
      value: "Prefers short messages",
      confidence: "confirmed"
    )
    inferred = create(
      :relationship_preference,
      relationship_profile: profile,
      key: "Restaurants",
      value: "May prefer quiet places",
      confidence: "inferred"
    )

    result = described_class.new(
      relationship_profile: profile,
      locale: :en,
      as_of: Date.new(2026, 8, 15)
    ).call

    expect(result.sources.map(&:id)).to include(
      "timeline:#{timeline.id}",
      "commitment:#{commitment.id}",
      "important_date:#{important_date.id}",
      "preference:#{confirmed.id}",
      "preference:#{inferred.id}"
    )
    expect(result.sources.find { |source| source.id == "preference:#{confirmed.id}" }.certainty).to eq("confirmed")
    expect(result.sources.find { |source| source.id == "preference:#{inferred.id}" }.certainty).to eq("inferred")
    expect(result.categories).to include("timeline", "commitments", "important_dates", "preferences")
    expect(result.fingerprint).to match(/\A[0-9a-f]{64}\z/)
  end

  it "excludes private and vault content unless each category is explicitly selected" do
    profile = create(:relationship_profile)
    create(:relationship_note, relationship_profile: profile, private: false, body: "Public update")
    create(:relationship_note, relationship_profile: profile, private: true, body: "Private update")
    create(
      :privacy_vault_item,
      relationship_profile: profile,
      payload: { "title" => "Protected note", "body" => "Vault update" }
    )

    public_result = described_class.new(relationship_profile: profile).call
    private_result = described_class.new(
      relationship_profile: profile,
      include_private_notes: true,
      include_vault_context: true
    ).call

    expect(public_result.sources.map(&:content).join(" ")).to include("Public update")
    expect(public_result.sources.map(&:content).join(" ")).not_to include("Private update", "Vault update")
    expect(private_result.sources.map(&:content).join(" ")).to include("Public update", "Private update", "Vault update")
    expect(private_result.sources.select(&:sensitive).map(&:kind)).to contain_exactly("private_note", "vault")
  end

  it "produces a stable fingerprint and changes it when source content changes" do
    profile = create(:relationship_profile)
    timeline = create(:timeline_entry, relationship_profile: profile, title: "Original title")

    original = described_class.new(relationship_profile: profile).call.fingerprint
    expect(described_class.new(relationship_profile: profile).call.fingerprint).to eq(original)

    timeline.update!(title: "Updated title")

    expect(described_class.new(relationship_profile: profile).call.fingerprint).not_to eq(original)
  end

  it "stabilizes tied important dates by record id before fingerprinting" do
    profile = create(:relationship_profile)
    first = create(:important_date, relationship_profile: profile, title: "Shared date", starts_on: Date.new(2026, 8, 20))
    second = create(:important_date, relationship_profile: profile, title: "Shared date", starts_on: Date.new(2026, 8, 20))
    dates = [ first, second ].sort_by(&:id)
    allow(profile).to receive(:upcoming_important_dates).and_return(dates.reverse)

    result = described_class.new(relationship_profile: profile, as_of: Date.new(2026, 8, 15)).call

    expect(result.sources.select { |source| source.kind == "important_date" }.map(&:id)).to eq(
      dates.map { |date| "important_date:#{date.id}" }
    )
  end

  it "uses the owner's timezone for the briefing date and timestamp labels" do
    user = create(:user)
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    profile = create(:relationship_profile, user:)
    timeline = create(
      :timeline_entry,
      relationship_profile: profile,
      title: "Late UTC update",
      occurred_at: Time.utc(2026, 8, 16, 1)
    )
    important_date = create(
      :important_date,
      relationship_profile: profile,
      title: "Local-day milestone",
      starts_on: Date.new(2026, 8, 15),
      recurrence: "none"
    )

    Timecop.freeze(Time.utc(2026, 8, 16, 1, 30)) do
      result = described_class.new(relationship_profile: profile, locale: :en).call

      expect(result.sources.map(&:id)).to include("important_date:#{important_date.id}")
      expect(result.sources.find { |source| source.id == "timeline:#{timeline.id}" }.label).to include("August 15, 2026")
    end
  end

  it "stabilizes tied vault items by record id before fingerprinting" do
    profile = create(:relationship_profile)
    tied_at = Time.zone.local(2026, 8, 15, 12)
    low_id = "00000000-0000-4000-8000-000000000001"
    high_id = "ffffffff-ffff-4fff-8fff-ffffffffffff"
    create(:privacy_vault_item, id: low_id, relationship_profile: profile, protected_at: tied_at, created_at: tied_at)
    create(:privacy_vault_item, id: high_id, relationship_profile: profile, protected_at: tied_at, created_at: tied_at)

    result = described_class.new(relationship_profile: profile, include_vault_context: true).call

    expect(result.sources.select { |source| source.kind == "vault" }.map(&:id)).to eq(
      [ "vault:#{high_id}", "vault:#{low_id}" ]
    )
  end

  it "reserves bounded catalog capacity for each explicitly selected sensitive category" do
    profile = create(:relationship_profile)
    8.times { |index| create(:timeline_entry, relationship_profile: profile, title: "Timeline #{index}") }
    8.times { |index| create(:commitment, relationship_profile: profile, title: "Commitment #{index}") }
    8.times { |index| create(:important_date, relationship_profile: profile, title: "Date #{index}", starts_on: Date.current + index.days) }
    8.times { |index| create(:relationship_preference, relationship_profile: profile, key: "Preference #{index}") }
    8.times { |index| create(:relationship_note, relationship_profile: profile, body: "Public note #{index}") }
    private_note = create(:relationship_note, relationship_profile: profile, private: true, body: "Selected private note")
    vault_item = create(:privacy_vault_item, relationship_profile: profile, payload: { "title" => "Selected vault item", "body" => "Vault context" })

    result = described_class.new(
      relationship_profile: profile,
      include_private_notes: true,
      include_vault_context: true
    ).call

    expect(result.sources.size).to be <= described_class::MAX_SOURCES
    expect(result.sources.map(&:id)).to include("private_note:#{private_note.id}", "vault:#{vault_item.id}")
  end
end
