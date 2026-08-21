require "rails_helper"

RSpec.describe GiftRecommendations::ContextBuilder do
  it "builds a bounded catalog from gift-relevant relationship memory" do
    profile = create(:relationship_profile)
    like = create(:relationship_preference, relationship_profile: profile, preference_type: "positive", key: "Coffee", value: "Light roasts", confidence: "confirmed")
    dislike = create(:relationship_preference, relationship_profile: profile, preference_type: "negative", key: "Candles", value: "Avoid scented candles", confidence: "confirmed")
    constraint = create(:relationship_preference, relationship_profile: profile, preference_type: "constraint", category: "allergies", key: "Materials", value: "No latex", confidence: "confirmed")
    desire = create(:desire, relationship_profile: profile, title: "Learn wheel pottery", category: "gift")
    gift = create(:gift, relationship_profile: profile, name: "Ceramic mug", status: "given", given_on: Date.new(2026, 7, 1))
    date = create(:important_date, relationship_profile: profile, title: "Birthday", starts_on: Date.new(2026, 9, 3), recurrence: "yearly")

    result = described_class.new(relationship_profile: profile, as_of: Date.new(2026, 8, 19)).call

    expect(result.sources.map(&:id)).to include(
      "profile:#{profile.id}",
      "preference:#{like.id}",
      "preference:#{dislike.id}",
      "preference:#{constraint.id}",
      "desire:#{desire.id}",
      "gift:#{gift.id}",
      "important_date:#{date.id}"
    )
    expect(result.categories).to include("relationship", "preferences", "constraints", "desires", "gift_history", "important_dates")
    expect(result.fingerprint).to match(/\A[0-9a-f]{64}\z/)
  end

  it "excludes private and vault context unless each source is explicitly selected" do
    profile = create(:relationship_profile)
    create(:relationship_note, relationship_profile: profile, private: false, body: "Public detail")
    private_note = create(:relationship_note, relationship_profile: profile, private: true, body: "Private detail")
    vault_item = create(
      :privacy_vault_item,
      relationship_profile: profile,
      suggestion_usage: "allowed",
      payload: { "title" => "Protected preference", "body" => "Vault detail" }
    )

    default_result = described_class.new(relationship_profile: profile).call
    selected_result = described_class.new(
      relationship_profile: profile,
      private_note_ids: [ private_note.id ],
      vault_item_ids: [ vault_item.id ]
    ).call

    expect(default_result.sources.map(&:content).join(" ")).to include("Public detail")
    expect(default_result.sources.map(&:content).join(" ")).not_to include("Private detail", "Vault detail")
    expect(selected_result.sources.map(&:content).join(" ")).to include("Private detail", "Vault detail")
    expect(selected_result.sources.select(&:sensitive).map(&:kind)).to contain_exactly("private_note", "vault")
  end

  it "excludes selected vault items that are not allowed for suggestions" do
    profile = create(:relationship_profile)
    excluded = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "excluded")

    result = described_class.new(relationship_profile: profile, vault_item_ids: [ excluded.id ]).call

    expect(result.sources.map(&:id)).not_to include("vault:#{excluded.id}")
  end

  it "prioritizes every bounded, explicitly selected source over ordinary context" do
    profile = create(:relationship_profile)
    private_notes = create_list(:relationship_note, 8, relationship_profile: profile, private: true)
    8.times do |index|
      create(:relationship_preference, relationship_profile: profile, key: "Preference #{index}")
    end
    create_list(:desire, 8, relationship_profile: profile)
    create_list(:gift, 8, relationship_profile: profile)
    create_list(:relationship_note, 8, relationship_profile: profile, private: false)

    result = described_class.new(
      relationship_profile: profile,
      private_note_ids: private_notes.map(&:id)
    ).call

    expect(result.sources.map(&:id)).to include(*private_notes.map { |note| "private_note:#{note.id}" })
    expect(result.sources.length).to be <= described_class::MAX_SOURCES
  end

  it "reserves bounded preference slots for constraints and dislikes" do
    profile = create(:relationship_profile)
    8.times do |index|
      create(:relationship_preference, relationship_profile: profile, key: "Preference #{index}")
    end
    dislike = create(
      :relationship_preference,
      relationship_profile: profile,
      preference_type: "negative",
      key: "Candles",
      value: "Avoid scented candles"
    )
    allergy = create(
      :relationship_preference,
      relationship_profile: profile,
      preference_type: "constraint",
      category: "allergies",
      key: "Materials",
      value: "No latex"
    )

    result = described_class.new(relationship_profile: profile).call

    expect(result.sources.map(&:id)).to include("preference:#{dislike.id}", "preference:#{allergy.id}")
    expect(result.sources.count { |source| source.id.start_with?("preference:") }).to eq(described_class::MAX_PER_KIND)
  end

  it "preserves every bounded hard constraint ahead of maximal sensitive context" do
    profile = create(:relationship_profile)
    private_notes = create_list(
      :relationship_note,
      described_class::MAX_PER_KIND,
      relationship_profile: profile,
      private: true,
      body: "private #{'p' * 1_000}"
    )
    vault_items = create_list(
      :privacy_vault_item,
      described_class::MAX_PER_KIND,
      relationship_profile: profile,
      suggestion_usage: "allowed",
      payload: { "title" => "Protected preference", "body" => "vault #{'v' * 1_000}" }
    )
    constraints = described_class::MAX_PER_KIND.times.map do |index|
      create(
        :relationship_preference,
        relationship_profile: profile,
        preference_type: index.even? ? "constraint" : "negative",
        category: index.even? ? "allergies" : "general",
        key: "Constraint #{index}",
        value: "avoid #{index} #{'x' * 1_000}"
      )
    end

    result = described_class.new(
      relationship_profile: profile,
      private_note_ids: private_notes.map(&:id),
      vault_item_ids: vault_items.map(&:id)
    ).call

    expect(result.sources.map(&:id)).to include(*constraints.map { |constraint| "preference:#{constraint.id}" })
    expect(result.sources.map(&:id)).to include(*private_notes.map { |note| "private_note:#{note.id}" })
    expect(result.sources.map(&:id)).to include(*vault_items.map { |item| "vault:#{item.id}" })
    expect(result.sources.select { |source| source.id.start_with?("preference:") }.map(&:kind)).to all(eq("constraint"))
    expect(result.sources.sum { |source| source.content.length }).to be <= described_class::MAX_TOTAL_CHARACTERS
  end

  it "uses stable ID tie-breakers when bounded gifts and desires otherwise compare equally" do
    profile = create(:relationship_profile)
    gift_ids = 9.downto(1).map { |sequence| format("00000000-0000-4000-8000-%012d", sequence) }
    desire_ids = 9.downto(1).map { |sequence| format("00000000-0000-4000-8001-%012d", sequence) }

    gift_ids.each do |id|
      create(:gift, id:, relationship_profile: profile, name: "Same gift", status: "idea", given_on: nil)
    end
    desire_ids.each do |id|
      create(:desire, id:, relationship_profile: profile, title: "Same desire", status: "active", captured_on: nil)
    end

    source_ids = described_class.new(relationship_profile: profile).call.sources.map(&:id)

    expect(source_ids.grep(/\Agift:/)).to eq(gift_ids.sort.first(described_class::MAX_PER_KIND).map { |id| "gift:#{id}" })
    expect(source_ids.grep(/\Adesire:/)).to eq(desire_ids.sort.first(described_class::MAX_PER_KIND).map { |id| "desire:#{id}" })
  end

  it "evaluates upcoming dates on the owner's local calendar" do
    user = create(:user)
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    profile = create(:relationship_profile, user:)
    important_date = create(
      :important_date,
      relationship_profile: profile,
      title: "Local-day occasion",
      starts_on: Date.new(2026, 8, 19),
      recurrence: "none"
    )

    result = Timecop.freeze(Time.utc(2026, 8, 20, 1, 30)) do
      described_class.new(relationship_profile: profile).call
    end

    expect(result.sources.map(&:id)).to include("important_date:#{important_date.id}")
  end
end
