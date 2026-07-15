require "rails_helper"

RSpec.describe "Interactions", type: :request do
  describe "GET /relationship_profiles/:id" do
    it "shows an unpersisted type-based suggestion and localized interaction history" do
      user = create(:user)
      profile = create(:relationship_profile, user:, type: "RelationshipProfiles::Friend")
      create(:interaction, relationship_profile: profile, notes: "Hablamos de la semana.")
      sign_in user

      I18n.with_locale(:es) { get relationship_profile_path(profile) }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ritmo de contacto")
      expect(response.body).to include("Cada 2 semanas")
      expect(response.body).to include("Hablamos de la semana.")
      expect(profile.reload.contact_cadence).to be_nil
    end

    it "uses uncertainty-aware overdue language and links to the existing reminder flow" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      Timecop.freeze(Time.zone.local(2026, 7, 1, 9)) { create(:contact_cadence, relationship_profile: profile, interval_days: 7) }
      Timecop.freeze(Time.zone.local(2026, 7, 14, 9)) { get relationship_profile_path(profile) }

      expect(response.body).to include("A little while since your last recorded check-in")
      expect(response.body).to include("You may have connected more recently")
      expect(response.body).to include(%(href="#{new_reminder_path(relationship_profile_id: profile.id)}"))
      expect(response.body).not_to include("You failed")
    end
  end

  describe "POST /relationship_profiles/:relationship_profile_id/interactions" do
    it "logs a manual meaningful interaction for an owned relationship" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        post relationship_profile_interactions_path(profile), params: {
          interaction: {
            interaction_type: "call",
            occurred_at: "2026-07-14T18:30",
            notes: "Caught up about the week.",
            origin: "derived",
            source_type: "ConversationRecap"
          }
        }, as: :turbo_stream
      end.to change(Interaction, :count).by(1)

      interaction = profile.interactions.reload.sole
      expect(interaction).to have_attributes(
        origin: "manual",
        interaction_type: "call",
        occurred_at: Time.zone.local(2026, 7, 14, 18, 30),
        notes: "Caught up about the week.",
        source: nil
      )
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(turbo-stream action="replace" target="contact_rhythm_section"))
    end

    it "does not log an interaction for another user's relationship" do
      sign_in create(:user)
      profile = create(:relationship_profile)

      expect do
        post relationship_profile_interactions_path(profile), params: { interaction: { interaction_type: "call", occurred_at: "2026-07-14T18:30" } }, as: :turbo_stream
      end.not_to change(Interaction, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "renders validation errors in the interaction frame" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_interactions_path(profile), params: { interaction: { interaction_type: "unknown", occurred_at: "" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(<turbo-frame id="new_interaction">))
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/interactions/:id" do
    it "updates a manual interaction but rejects a derived source interaction" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      manual = create(:interaction, relationship_profile: profile)
      derived = create(:interaction, :derived_from_conversation_recap, relationship_profile: profile, source: create(:conversation_recap, relationship_profile: profile))
      sign_in user

      patch relationship_profile_interaction_path(profile, manual), params: { interaction: { notes: "Updated note", interaction_type: "call", occurred_at: "2026-07-14T18:30" } }
      expect(manual.reload.notes).to eq("Updated note")

      patch relationship_profile_interaction_path(profile, derived), params: { interaction: { notes: "Forged" } }
      expect(response).to have_http_status(:forbidden)
      expect(derived.reload.display_notes).not_to eq("Forged")
    end
  end

  describe "DELETE /relationship_profiles/:relationship_profile_id/interactions/:id" do
    it "deletes an owned manual interaction" do
      interaction = create(:interaction)
      sign_in interaction.relationship_profile.user

      expect do
        delete relationship_profile_interaction_path(interaction.relationship_profile, interaction), as: :turbo_stream
      end.to change(Interaction, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
