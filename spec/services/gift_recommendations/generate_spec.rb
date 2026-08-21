require "rails_helper"

RSpec.describe GiftRecommendations::Generate do
  it "persists source-backed recommendations and rejects repeated prior gifts by default" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "ask_every_time")
    profile = create(:relationship_profile, user:)
    preference = create(:relationship_preference, relationship_profile: profile, key: "Coffee", value: "Light roasts", confidence: "confirmed")
    create(:gift, relationship_profile: profile, name: "Ceramic mug", status: "given", given_on: Date.new(2026, 7, 1))
    generator = double(generate: [
      {
        "title" => "Ceramic mug",
        "rationale" => "Matches the coffee preference.",
        "source_ids" => [ "preference:#{preference.id}" ],
        "estimated_price_cents" => 2_500,
        "vendor" => nil
      },
      {
        "title" => "Light-roast tasting set",
        "rationale" => "Builds on the confirmed coffee preference.",
        "source_ids" => [ "preference:#{preference.id}" ],
        "estimated_price_cents" => 4_000,
        "vendor" => "Local roaster"
      }
    ])

    recommendations = described_class.call(
      actor: user,
      relationship_profile: profile,
      budget_cents: 5_000,
      occasion: "Birthday",
      explicitly_approved: true,
      generator:
    )

    expect(recommendations.map(&:title)).to eq([ "Light-roast tasting set" ])
    expect(recommendations.sole.source_context.sole).to include(
      "id" => "preference:#{preference.id}",
      "sensitive" => false
    )
    expect(AuditEvent.where(user:, action: "gift_recommendation.generated", target: profile)).to exist
  end

  it "fails closed when the gift-suggestion permission is disabled" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    generator = double

    expect(generator).not_to receive(:generate)
    expect do
      described_class.call(actor: user, relationship_profile: profile, explicitly_approved: true, generator:)
    end.to raise_error(GiftRecommendations::PermissionDeniedError)
  end

  it "requires an active vault lease before reading selected protected context" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    vault_item = create(:privacy_vault_item, relationship_profile: profile)

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        vault_item_ids: [ vault_item.id ],
        generator: double
      )
    end.to raise_error(GiftRecommendations::VaultAccessError)
  end

  it "fails closed when a selected vault item is excluded from suggestions" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    vault_item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "excluded")

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        vault_item_ids: [ vault_item.id ],
        vault_lease: PrivacyVault::Lease.issue_for(user),
        generator: double
      )
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "rejects provider output when relationship sources change during generation" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    preference = create(:relationship_preference, relationship_profile: profile, key: "Coffee", value: "Light roasts")
    generator = double
    allow(generator).to receive(:generate) do
      preference.update!(value: "No coffee gifts")
      [
        {
          "title" => "Coffee tasting set",
          "rationale" => "Matches the old preference.",
          "source_ids" => [ "preference:#{preference.id}" ],
          "estimated_price_cents" => 4_000,
          "vendor" => nil
        }
      ]
    end

    expect do
      described_class.call(actor: user, relationship_profile: profile, generator:)
    end.to raise_error(GiftRecommendations::GenerationSupersededError)
    expect(profile.gift_recommendations).to be_empty
  end

  it "refreshes duplicate gift titles after provider generation" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    8.times { |index| create(:gift, relationship_profile: profile, name: "Gift #{index}") }
    generator = double
    allow(generator).to receive(:generate) do
      create(:gift, relationship_profile: profile, name: "ZZ Concurrent gift")
      [
        {
          "title" => "ZZ Concurrent gift",
          "rationale" => "Matches the relationship context.",
          "source_ids" => [ "profile:#{profile.id}" ],
          "estimated_price_cents" => 4_000,
          "vendor" => nil
        }
      ]
    end

    expect do
      described_class.call(actor: user, relationship_profile: profile, generator:)
    end.to raise_error(GiftRecommendations::GenerationError, "Gift recommendation response had no usable ideas")
    expect(profile.gift_recommendations).to be_empty
  end

  it "rejects provider output when permission is revoked during generation" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    generator = double
    allow(generator).to receive(:generate) do
      AutomationPermissions::Change.call(
        user:,
        actor: user,
        capability: "suggest_gifts",
        mode: "disabled"
      )
      [
        {
          "title" => "Coffee tasting set",
          "rationale" => "Matches the relationship context.",
          "source_ids" => [ "profile:#{profile.id}" ],
          "estimated_price_cents" => 4_000,
          "vendor" => nil
        }
      ]
    end

    expect do
      described_class.call(actor: user, relationship_profile: profile, generator:)
    end.to raise_error(GiftRecommendations::PermissionDeniedError)
    expect(profile.gift_recommendations).to be_empty
  end

  it "fails closed for unknown evidence and over-budget output" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)

    unknown_source = double(generate: [
      {
        "title" => "Invented gift",
        "rationale" => "Invented reason.",
        "source_ids" => [ "preference:unknown" ],
        "estimated_price_cents" => 2_000,
        "vendor" => nil
      }
    ])
    expect do
      described_class.call(actor: user, relationship_profile: profile, generator: unknown_source)
    end.to raise_error(GiftRecommendations::GenerationError, "Gift recommendation cited an unknown source")

    relationship_source = "profile:#{profile.id}"
    over_budget = double(generate: [
      {
        "title" => "Weekend trip",
        "rationale" => "Fits the relationship context.",
        "source_ids" => [ relationship_source ],
        "estimated_price_cents" => 20_000,
        "vendor" => nil
      }
    ])
    expect do
      described_class.call(actor: user, relationship_profile: profile, budget_cents: 5_000, generator: over_budget)
    end.to raise_error(GiftRecommendations::GenerationError, "Gift recommendation exceeded the requested budget")
    expect(profile.gift_recommendations).to be_empty
  end

  it "rejects an unpriced recommendation when a maximum budget was supplied" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    generator = double(generate: [
      {
        "title" => "Mystery experience",
        "rationale" => "The provider did not estimate its price.",
        "source_ids" => [ "profile:#{profile.id}" ],
        "estimated_price_cents" => nil,
        "vendor" => nil
      }
    ])

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        budget_cents: 5_000,
        generator:
      )
    end.to raise_error(GiftRecommendations::GenerationError, "Gift recommendation response was invalid")
    expect(profile.gift_recommendations).to be_empty
  end

  it "replaces one reviewed idea with a distinct alternative" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    previous = create(:gift_recommendation, user:, relationship_profile: profile, title: "Coffee tasting set")
    generator = double(generate: [
      {
        "title" => "Coffee brewing workshop",
        "rationale" => "Offers a different way to explore coffee.",
        "source_ids" => [ "profile:#{profile.id}" ],
        "estimated_price_cents" => 5_000,
        "vendor" => nil
      }
    ])

    replacement = described_class.call(
      actor: user,
      relationship_profile: profile,
      replace: previous,
      generator:
    ).sole

    expect(previous.reload).to be_dismissed
    expect(replacement).to be_generated
    expect(replacement.title).to eq("Coffee brewing workshop")
  end

  it "rejects the same replacement title even when repeatable staples are allowed" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    previous = create(:gift_recommendation, user:, relationship_profile: profile, title: "Coffee tasting set", allow_repeats: true)
    generator = double(generate: [
      {
        "title" => "Coffee tasting set",
        "rationale" => "Repeats the same idea.",
        "source_ids" => [ "profile:#{profile.id}" ],
        "estimated_price_cents" => 5_000,
        "vendor" => nil
      }
    ])

    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        allow_repeats: true,
        replace: previous,
        generator:
      )
    end.to raise_error(GiftRecommendations::GenerationError, "Gift recommendation response had no usable ideas")
    expect(previous.reload).to be_generated
  end

  it "rejects an alternative when the original is saved during generation" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    previous = create(:gift_recommendation, user:, relationship_profile: profile)
    generator = double
    allow(generator).to receive(:generate) do
      GiftRecommendation.where(id: previous.id).update_all(status: "saved", saved_at: Time.current, updated_at: Time.current)
      [
        {
          "title" => "Coffee brewing workshop",
          "rationale" => "A distinct idea.",
          "source_ids" => [ "profile:#{profile.id}" ],
          "estimated_price_cents" => 5_000,
          "vendor" => nil
        }
      ]
    end

    expect do
      described_class.call(actor: user, relationship_profile: profile, replace: previous, generator:)
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(previous.reload).to be_saved
  end

  it "keeps recommendation titles out of the provider payload while filtering them locally" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    create(:gift_recommendation, user:, relationship_profile: profile, title: "Private-derived pottery idea")
    41.times { |index| create(:gift, relationship_profile: profile, name: "Gift #{index} #{'x' * 220}") }
    generator = double
    allow(generator).to receive(:generate) do |excluded_titles:, **|
      expect(excluded_titles.length).to be <= 40
      expect(excluded_titles).to all(satisfy { |title| title.length <= 200 })
      expect(excluded_titles).not_to include("Private-derived pottery idea")
      [
        {
          "title" => "Private-derived pottery idea",
          "rationale" => "Repeats a prior derived idea.",
          "source_ids" => [ "profile:#{profile.id}" ],
          "estimated_price_cents" => 5_000,
          "vendor" => nil
        }
      ]
    end

    expect do
      described_class.call(actor: user, relationship_profile: profile, generator:)
    end.to raise_error(GiftRecommendations::GenerationError, "Gift recommendation response had no usable ideas")
  end

  it "keeps same-batch recommendation titles unique when prior repeats are allowed" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    repeated_result = {
      "title" => "Coffee tasting set",
      "rationale" => "Matches the relationship context.",
      "source_ids" => [ "profile:#{profile.id}" ],
      "estimated_price_cents" => 4_000,
      "vendor" => nil
    }
    generator = double(generate: [ repeated_result, repeated_result ])

    recommendations = described_class.call(
      actor: user,
      relationship_profile: profile,
      allow_repeats: true,
      generator:
    )

    expect(recommendations.map(&:title)).to eq([ "Coffee tasting set" ])
  end

  it "allows repeated gift history without duplicating a visible recommendation" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    create(:gift, relationship_profile: profile, name: "Ceramic mug")
    create(:gift_recommendation, user:, relationship_profile: profile, title: "Coffee tasting set")
    generator = double
    allow(generator).to receive(:generate) do |excluded_titles:, **|
      expect(excluded_titles).not_to include("Ceramic mug")
      [
        {
          "title" => "Coffee tasting set",
          "rationale" => "Duplicates an idea already visible for review.",
          "source_ids" => [ "profile:#{profile.id}" ],
          "estimated_price_cents" => 4_000,
          "vendor" => nil
        },
        {
          "title" => "Ceramic mug",
          "rationale" => "A repeatable staple from prior gift history.",
          "source_ids" => [ "profile:#{profile.id}" ],
          "estimated_price_cents" => 3_000,
          "vendor" => nil
        }
      ]
    end

    recommendations = described_class.call(
      actor: user,
      relationship_profile: profile,
      allow_repeats: true,
      generator:
    )

    expect(recommendations.map(&:title)).to eq([ "Ceramic mug" ])
  end

  it "rejects needed-by dates beyond the supported persistence range before generation" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    generator = double

    expect(generator).not_to receive(:generate)
    expect do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        needed_by: "9999999999-01-01",
        generator:
      )
    end.to raise_error(GiftRecommendations::GenerationError, "Gift recommendation date was invalid")
  end

  it "validates needed-by dates on the owner's local calendar" do
    user = create(:user)
    create(:notification_preference, user:, time_zone: "America/Costa_Rica")
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "allow_automatically")
    profile = create(:relationship_profile, user:)
    generator = double(generate: [
      {
        "title" => "Local-day gift",
        "rationale" => "Fits the relationship context.",
        "source_ids" => [ "profile:#{profile.id}" ],
        "estimated_price_cents" => 5_000,
        "vendor" => nil
      }
    ])

    recommendations = Timecop.freeze(Time.utc(2026, 8, 20, 1, 30)) do
      described_class.call(
        actor: user,
        relationship_profile: profile,
        needed_by: Date.new(2026, 8, 19),
        generator:
      )
    end

    expect(recommendations.sole.needed_by).to eq(Date.new(2026, 8, 19))
  end
end
