require "rails_helper"

RSpec.describe "Professional relationships", type: :request do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }

  before { sign_in user }

  it "saves mode and selected work context through the owner profile form and exports it" do
    commitment = create(:commitment, relationship_profile: profile, title: "Follow up on proposal")
    patch relationship_profile_path(profile), params: { relationship_profile: {
      relationship_mode: "professional", professional_context: { organization: "Acme", commitments: [ "", commitment.id ] }
    } }
    expect(response).to redirect_to(relationship_profile_path(profile))
    expect(profile.reload.professional_context).to include("organization" => "Acme", "commitments" => [ commitment.id ])
    get relationship_profile_path(profile)
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.body).to include("Acme", "Add client milestones", "Prepare a meeting or performance review")
    snapshot = DataExports::Snapshot.new(user:, relationship_profile: profile).to_h
    expect(snapshot.fetch("relationship_profiles").first.fetch("professional_context")).to include("organization" => "Acme")
  end

  it "rejects cross-owner and same-owner other-profile source IDs and unpermitted fields" do
    [ create(:commitment), create(:commitment, relationship_profile: create(:relationship_profile, user:)) ].each do |foreign|
      patch relationship_profile_path(profile), params: { relationship_profile: {
        relationship_mode: "professional", professional_context: { commitments: [ foreign.id ] }, user_id: create(:user).id
      } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(profile.reload).not_to be_professional
      expect(profile.user_id).to eq(user.id)
    end
    patch relationship_profile_path(create(:relationship_profile)), params: { relationship_profile: { relationship_mode: "professional" } }
    expect(response).to have_http_status(:not_found)
  end

  it "renders both locales with associated form labels and filtered professional parameters" do
    %i[en es].each do |locale|
      I18n.with_locale(locale) do
        get edit_relationship_profile_path(profile)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("professional_relationships.fields.review_preparation"))
        expect(response.body).to include('for="professional_review_preparation"')
        expect(response.body).not_to include("translation_missing")
      end
    end
    filtered = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter("professional_context" => { "organization" => "Secret" })
    expect(filtered["professional_context"]).to eq("[FILTERED]")
  end
end
