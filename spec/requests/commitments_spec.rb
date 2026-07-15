require "cgi"
require "rails_helper"

RSpec.describe "Commitments", type: :request do
  describe "GET /relationship_profiles/:relationship_profile_id" do
    it "renders commitments with reminder and overdue context" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "John")
      commitment = create(:commitment, relationship_profile: profile, title: "Send article to John", due_on: 1.day.ago.to_date)
      create(:reminder, user:, relationship_profile: profile, commitment:, title: "Send the article", scheduled_at: 1.hour.from_now)
      sign_in user

      get relationship_profile_path(profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Promises &amp; commitments")
      expect(response.body).to include("Send article to John")
      expect(response.body).to include("Overdue")
      expect(response.body).to include("1 reminder")
      expect(CGI.unescapeHTML(response.body)).to include(new_reminder_path(relationship_profile_id: profile.id, commitment_id: commitment.id))
    end

    it "preserves the active timeline filter across commitment actions" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      commitment = create(:commitment, relationship_profile: profile)
      sign_in user

      get relationship_profile_path(profile, timeline_type: "promise")

      body = CGI.unescapeHTML(response.body)
      expect(body).to include(new_relationship_profile_commitment_path(profile, timeline_type: "promise"))
      expect(body).to include(edit_relationship_profile_commitment_path(profile, commitment, timeline_type: "promise"))
      expect(body).to include(complete_relationship_profile_commitment_path(profile, commitment, timeline_type: "promise"))
      expect(body).to include(cancel_relationship_profile_commitment_path(profile, commitment, timeline_type: "promise"))
      expect(body).to include(relationship_profile_commitment_path(profile, commitment, timeline_type: "promise"))
    end

    it "renders Spanish copy without falling back to English" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:commitment, relationship_profile: profile, title: "Enviar el artículo")
      sign_in user

      I18n.with_locale(:es) { get relationship_profile_path(profile) }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Promesas y compromisos")
      expect(response.body).to include("Enviar el artículo")
      expect(response.body).not_to include("Promises &amp; commitments")
      expect(response.body).not_to include("Translation missing")
    end
  end

  describe "POST /relationship_profiles/:relationship_profile_id/commitments" do
    it "creates a manual commitment and protected timeline entry through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        expect do
          post relationship_profile_commitments_path(profile), params: {
            commitment: { title: "  Send the article  ", notes: "Add a short summary.", due_on: "2026-07-20", status: "open" }
          }, as: :turbo_stream
        end.to change(Commitment, :count).by(1)
      end.to change(TimelineEntry, :count).by(1)

      commitment = profile.commitments.reload.sole
      expect(commitment).to have_attributes(title: "Send the article", notes: "Add a short summary.", due_on: Date.new(2026, 7, 20), status: "open")
      expect(commitment.timeline_entry).to have_attributes(
        relationship_profile_id: profile.id,
        entry_type: "promise",
        origin: "system",
        title: "Send the article",
        source_record: commitment
      )
      expect(response.body).to include(%(target="commitments_section"))
      expect(response.body).to include(%(target="timeline_entries_section"))
    end

    it "does not create a commitment for another owner's relationship" do
      sign_in create(:user)
      profile = create(:relationship_profile)

      expect do
        post relationship_profile_commitments_path(profile), params: { commitment: { title: "Private promise" } }, as: :turbo_stream
      end.not_to change(Commitment, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "renders localized validation errors in the new frame" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_commitments_path(profile), params: { commitment: { title: "", status: "invented" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(<turbo-frame id="new_commitment">))
      expect(CGI.unescapeHTML(response.body)).to include("Title can't be blank")
    end
  end

  describe "GET commitment forms" do
    it "wraps new and edit forms in their targeted Turbo frames" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      commitment = create(:commitment, relationship_profile: profile)
      sign_in user

      get new_relationship_profile_commitment_path(profile)
      expect(response.body).to include(%(<turbo-frame id="new_commitment">))

      get edit_relationship_profile_commitment_path(profile, commitment)
      expect(response.body).to include(%(<turbo-frame id="commitment_#{commitment.id}">))
    end
  end

  describe "archived relationships" do
    it "does not offer reminder creation for a commitment" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      commitment = create(:commitment, relationship_profile: profile)
      profile.discard!
      sign_in user

      get relationship_profile_path(profile)

      expect(response.body).not_to include(new_reminder_path(relationship_profile_id: profile.id, commitment_id: commitment.id))
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/commitments/:id" do
    it "updates the commitment and its timeline entry atomically" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      commitment = create(:commitment, relationship_profile: profile, title: "Old title")
      create(:timeline_entry, relationship_profile: profile, source_record: commitment, entry_type: "promise", origin: "system", title: "Old title")
      sign_in user

      patch relationship_profile_commitment_path(profile, commitment), params: {
        commitment: { title: "New title", notes: "New context", due_on: "2026-07-25" }
      }, as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(commitment.reload).to have_attributes(title: "New title", notes: "New context", due_on: Date.new(2026, 7, 25))
      expect(commitment.timeline_entry).to have_attributes(title: "New title", body: "New context")
    end
  end

  describe "status transitions" do
    it "completes, reopens, and cancels a commitment" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      commitment = create(:commitment, relationship_profile: profile)
      create(:timeline_entry, relationship_profile: profile, source_record: commitment, entry_type: "promise", origin: "system", title: commitment.title)
      sign_in user

      patch complete_relationship_profile_commitment_path(profile, commitment), as: :turbo_stream
      expect(commitment.reload).to be_completed
      expect(commitment.timeline_entry).to have_attributes(title: commitment.title, source_record: commitment)

      patch reopen_relationship_profile_commitment_path(profile, commitment), as: :turbo_stream
      expect(commitment.reload).to be_open

      patch cancel_relationship_profile_commitment_path(profile, commitment), as: :turbo_stream
      expect(commitment.reload).to be_canceled
    end
  end

  describe "DELETE /relationship_profiles/:relationship_profile_id/commitments/:id" do
    it "deletes the commitment, timeline entry, and owned reminders" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      commitment = create(:commitment, relationship_profile: profile)
      create(:timeline_entry, relationship_profile: profile, source_record: commitment, entry_type: "promise", origin: "system", title: commitment.title)
      create(:reminder, user:, relationship_profile: profile, commitment:)
      sign_in user

      expect do
        expect do
          expect do
            delete relationship_profile_commitment_path(profile, commitment), as: :turbo_stream
          end.to change(Commitment, :count).by(-1)
        end.to change(TimelineEntry, :count).by(-1)
      end.to change(Reminder, :count).by(-1)
    end
  end
end
