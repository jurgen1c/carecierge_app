require "rails_helper"

RSpec.describe "Gift recommendations", type: :request do
  it "renders an inline, localized workspace for an active owner profile" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    sign_in user

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("gift-recommendations")
    expect(response.body).to include("Gift recommendations")
    expect(response.body).to include("Nothing is purchased automatically")
  end

  it "saves and marks a recommendation purchased through owner-scoped actions" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    saved = create(:gift_recommendation, user:, relationship_profile: profile, title: "Coffee sampler")
    purchased = create(:gift_recommendation, user:, relationship_profile: profile, title: "Pottery class", estimated_price_cents: 8_000)
    sign_in user

    expect do
      patch save_relationship_profile_gift_recommendation_path(profile, saved)
    end.to change(profile.gifts, :count).by(1)
    expect(saved.reload).to be_saved
    expect(profile.gifts.order(:created_at).last).to have_attributes(name: "Coffee sampler", status: "idea")

    expect do
      patch purchase_relationship_profile_gift_recommendation_path(profile, purchased)
    end.to change(profile.gifts, :count).by(1)
    expect(purchased.reload).to be_purchased
    expect(profile.gifts.order(:created_at).last).to have_attributes(name: "Pottery class", status: "planned", price_cents: 8_000)
  end

  it "does not expose another account's recommendation" do
    recommendation = create(:gift_recommendation)
    other_user = create(:user)
    other_profile = create(:relationship_profile, user: other_user)
    sign_in other_user

    patch dismiss_relationship_profile_gift_recommendation_path(other_profile, recommendation)

    expect(response).to have_http_status(:not_found)
    expect(recommendation.reload).to be_generated
  end

  it "passes bounded request settings and explicit sensitive-context choices to generation" do
    user = create(:user)
    create(:automation_permission, user:, capability: "suggest_gifts", mode: "ask_every_time")
    profile = create(:relationship_profile, user:)
    private_note = create(:relationship_note, relationship_profile: profile, private: true, body: "Private pottery interest")
    allow(GiftRecommendations::Generate).to receive(:call).and_return([])
    sign_in user

    post generate_relationship_profile_gift_recommendations_path(profile), params: {
      gift_recommendation: {
        budget: "75.50",
        needed_by: "2026-09-01",
        occasion: "Birthday",
        allow_repeats: "1",
        include_private_notes: "1"
      }
    }

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "gift-recommendations"))
    expect(GiftRecommendations::Generate).to have_received(:call).with(hash_including(
      actor: user,
      relationship_profile: have_attributes(id: profile.id),
      budget_cents: 7_550,
      needed_by: "2026-09-01",
      occasion: "Birthday",
      allow_repeats: true,
      private_note_ids: [ private_note.id ],
      vault_item_ids: [],
      explicitly_approved: true,
      locale: :en
    ))
  end

  it "requires a current vault lease before selected protected context reaches generation" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:privacy_vault_item, relationship_profile: profile)
    allow(GiftRecommendations::Generate).to receive(:call)
    sign_in user

    post generate_relationship_profile_gift_recommendations_path(profile), params: {
      gift_recommendation: { include_vault_context: "1" }
    }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(profile))
    expect(GiftRecommendations::Generate).not_to have_received(:call)
  end

  it "requires a fresh choice before reusing sensitive sources for an alternative" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    private_note = create(:relationship_note, relationship_profile: profile, private: true)
    recommendation = create(
      :gift_recommendation,
      user:,
      relationship_profile: profile,
      source_context: [
        {
          "id" => "private_note:#{private_note.id}",
          "label" => "Private note",
          "certainty" => "confirmed",
          "sensitive" => true
        }
      ]
    )
    allow(GiftRecommendations::Generate).to receive(:call).and_return([])
    sign_in user

    post alternative_relationship_profile_gift_recommendation_path(profile, recommendation)

    expect(GiftRecommendations::Generate).to have_received(:call).with(hash_including(
      private_note_ids: [],
      vault_item_ids: []
    ))

    post alternative_relationship_profile_gift_recommendation_path(profile, recommendation), params: {
      gift_recommendation: { include_private_notes: "1" }
    }

    expect(GiftRecommendations::Generate).to have_received(:call).with(hash_including(
      private_note_ids: [ private_note.id ],
      vault_item_ids: []
    ))
  end

  it "rejects non-finite and extreme compact budget inputs without materializing them" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    allow(GiftRecommendations::Generate).to receive(:call).and_return([])
    sign_in user

    [ "NaN", "1e999999999" ].each do |budget|
      post generate_relationship_profile_gift_recommendations_path(profile), params: {
        gift_recommendation: { budget: }
      }
    end

    expect(GiftRecommendations::Generate).to have_received(:call).twice.with(hash_including(budget_cents: -1))
  end
end
