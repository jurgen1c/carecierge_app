require "rails_helper"

RSpec.describe "Contact cadences", type: :request do
  describe "POST /relationship_profiles/:relationship_profile_id/contact_cadence" do
    it "accepts a supported cadence for an owned relationship" do
      user = create(:user)
      profile = create(:relationship_profile, user:, type: "RelationshipProfiles::Friend")
      sign_in user

      expect do
        post relationship_profile_contact_cadence_path(profile), params: { contact_cadence: { interval_days: 14 } }, as: :turbo_stream
      end.to change(ContactCadence, :count).by(1)

      expect(profile.reload.contact_cadence.interval_days).to eq(14)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(turbo-stream action="replace" target="contact_rhythm_section"))
    end

    it "does not accept cadence for another user's relationship" do
      sign_in create(:user)
      profile = create(:relationship_profile)

      expect do
        post relationship_profile_contact_cadence_path(profile), params: { contact_cadence: { interval_days: 14 } }, as: :turbo_stream
      end.not_to change(ContactCadence, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "renders localized validation errors without replacing the suggestion" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_contact_cadence_path(profile), params: { contact_cadence: { interval_days: 13 } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(<turbo-frame id="contact_cadence_form">))
      expect(profile.reload.contact_cadence).to be_nil
    end

    it "keeps cadence controls available for an owned archived relationship" do
      user = create(:user)
      profile = create(:relationship_profile, user:, discarded_at: Time.current)
      sign_in user

      expect do
        post relationship_profile_contact_cadence_path(profile), params: { contact_cadence: { interval_days: 30 } }, as: :turbo_stream
      end.to change(ContactCadence, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(profile.reload.contact_cadence.interval_days).to eq(30)
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/contact_cadence" do
    it "adjusts the owned relationship cadence" do
      cadence = create(:contact_cadence, interval_days: 14)
      sign_in cadence.relationship_profile.user

      patch relationship_profile_contact_cadence_path(cadence.relationship_profile), params: { contact_cadence: { interval_days: 30 } }, as: :turbo_stream

      expect(cadence.reload.interval_days).to eq(30)
      expect(response).to have_http_status(:ok)
    end
  end
end
