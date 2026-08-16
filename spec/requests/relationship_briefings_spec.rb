require "rails_helper"

RSpec.describe "Relationship briefings", type: :request do
  it "renders the inline briefing workspace near the top of an active profile" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    sign_in user

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body.index("relationship-briefing")).to be < response.body.index("message-drafting")
    expect(response.body).to include("Nothing is sent or scheduled automatically")
  end

  it "generates, saves, and dismisses an owner-scoped briefing" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    briefing = build(:relationship_briefing, user:, relationship_profile: profile)
    allow(RelationshipBriefings::Generate).to receive(:call).and_return(briefing)
    sign_in user

    post generate_relationship_profile_relationship_briefings_path(profile), params: {
      relationship_briefing: { interaction_context: "Dinner after her first week", include_private_notes: "1" }
    }
    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "relationship-briefing"))
    expect(RelationshipBriefings::Generate).to have_received(:call).with(hash_including(
      actor: user,
      relationship_profile: have_attributes(id: profile.id, user_id: user.id),
      interaction_context: "Dinner after her first week",
      include_private_notes: true,
      include_vault_context: false,
      locale: :en
    ))

    briefing.save!
    patch save_relationship_profile_relationship_briefing_path(profile, briefing)
    expect(briefing.reload).to be_saved
    patch dismiss_relationship_profile_relationship_briefing_path(profile, briefing)
    expect(briefing.reload).to be_dismissed
  end

  it "does not allow another account to mutate a briefing" do
    briefing = create(:relationship_briefing)
    other_user = create(:user)
    other_profile = create(:relationship_profile, user: other_user)
    sign_in other_user

    patch save_relationship_profile_relationship_briefing_path(other_profile, briefing)

    expect(response).to have_http_status(:not_found)
    expect(briefing.reload).to be_generated
  end

  it "requires an active vault lease before including vault context" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    sign_in user

    post generate_relationship_profile_relationship_briefings_path(profile), params: {
      relationship_briefing: { interaction_context: "A private conversation", include_vault_context: "1" }
    }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(profile))
    expect(profile.relationship_briefings).to be_empty
  end

  it "preserves retry input and consent when generation fails" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    allow(RelationshipBriefings::Generate).to receive(:call).and_raise(RelationshipBriefings::GenerationError)
    sign_in user

    post generate_relationship_profile_relationship_briefings_path(profile), params: {
      relationship_briefing: {
        interaction_context: "Dinner after a difficult week",
        include_private_notes: "1"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css("#flash").text).to include("We couldn't create the briefing")
    expect(document.at_css("#relationship_briefing_interaction_context").text).to include("Dinner after a difficult week")
    expect(document.at_css("#relationship_briefing_include_private_notes")["checked"]).to eq("checked")
  end

  it "handles a stale save after another request dismisses the briefing" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    briefing = create(:relationship_briefing, user:, relationship_profile: profile, status: "dismissed", dismissed_at: Time.current)
    sign_in user

    patch save_relationship_profile_relationship_briefing_path(profile, briefing)

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "relationship-briefing"))
    follow_redirect!
    expect(response.body).to include("This briefing is no longer available to save")
  end

  it "locks the account, profile, and briefing in canonical order when saving" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    briefing = create(:relationship_briefing, user:, relationship_profile: profile)
    lock_sql = []
    subscriber = lambda do |*, payload|
      sql = payload.fetch(:sql)
      lock_sql << sql if sql.include?("FOR UPDATE")
    end
    sign_in user

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      patch save_relationship_profile_relationship_briefing_path(profile, briefing)
    end

    user_lock = lock_sql.index { |sql| sql.include?('FROM "users"') }
    profile_lock = lock_sql.index { |sql| sql.include?('FROM "relationship_profiles"') }
    briefing_lock = lock_sql.index { |sql| sql.include?('FROM "relationship_briefings"') }
    expect(user_lock).to be < profile_lock
    expect(profile_lock).to be < briefing_lock
  end
end
