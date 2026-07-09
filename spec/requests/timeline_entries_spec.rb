require "cgi"
require "rails_helper"

RSpec.describe "Timeline entries", type: :request do
  describe "GET /relationship_profiles/:id" do
    it "renders a filtered relationship timeline with unboxed feed rows and context summary" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Ana")
      create(:timeline_entry, relationship_profile: profile, entry_type: "note", title: "Called after dinner", occurred_at: Time.zone.local(2026, 7, 8, 18, 0, 0))
      create(:timeline_entry, relationship_profile: profile, entry_type: "gift", title: "Logged birthday gift", occurred_at: Time.zone.local(2026, 7, 7, 9, 0, 0))
      sign_in user

      get relationship_profile_path(profile, timeline_type: "gift")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Relationship timeline")
      expect(response.body).to include("Logged birthday gift")
      expect(response.body).not_to include("Called after dinner")
      expect(response.body).to include("1 shown")
      expect(response.body).to include("Ready for system entries")
      expect(response.body).to include(%(href="#{new_relationship_profile_timeline_entry_path(profile, timeline_type: "gift")}"))
      expect(response.body).to include(%(data-turbo-frame="new_timeline_entry"))
      expect(response.body).to include(%(data-timeline-entry-row="true"))
    end

    it "renders localized timeline copy in Spanish" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:timeline_entry, relationship_profile: profile, title: "Llamada familiar")
      sign_in user

      I18n.with_locale(:es) do
        get relationship_profile_path(profile)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cronología de la relación")
      expect(response.body).to include("Agregar entrada")
      expect(response.body).not_to include("Relationship timeline")
      expect(response.body).not_to include("Translation missing")
    end
  end

  describe "POST /relationship_profiles/:relationship_profile_id/timeline_entries" do
    it "creates a manual timeline entry through Turbo without accepting system fields" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      gift = create(:gift, relationship_profile: profile)
      create(:timeline_entry, relationship_profile: profile, entry_type: "note", title: "Hidden note")
      sign_in user

      expect do
        post relationship_profile_timeline_entries_path(profile, timeline_type: "gift"),
          params: {
            timeline_entry: {
              title: "Logged gift idea",
              body: "Follow up before Friday.",
              entry_type: "gift",
              occurred_at: "2026-07-08T14:30",
              origin: "system",
              source_record_type: "Gift",
              source_record_id: gift.id
            }
          },
          as: :turbo_stream
      end.to change(TimelineEntry, :count).by(1)

      entry = profile.timeline_entries.reload.find_by!(title: "Logged gift idea")
      expect(entry).to have_attributes(
        title: "Logged gift idea",
        body: "Follow up before Friday.",
        entry_type: "gift",
        origin: "manual",
        source_record: nil
      )
      expect(entry.occurred_at).to eq(Time.zone.local(2026, 7, 8, 14, 30, 0))
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="timeline_entries_section"))
      expect(response.body).to include("Logged gift idea")
      expect(response.body).not_to include("Hidden note")
      expect(response.body).to include(%(timeline_type=gift))
    end

    it "does not create a timeline entry for another user's profile" do
      sign_in create(:user)
      profile = create(:relationship_profile)

      expect do
        post relationship_profile_timeline_entries_path(profile),
          params: { timeline_entry: { title: "Private", entry_type: "note", occurred_at: "2026-07-08T14:30" } },
          as: :turbo_stream
      end.not_to change(TimelineEntry, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "renders validation errors in the new frame" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        post relationship_profile_timeline_entries_path(profile),
          params: { timeline_entry: { title: "", entry_type: "unknown", occurred_at: "" } },
          as: :turbo_stream
      end.not_to change(TimelineEntry, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(<turbo-frame id="new_timeline_entry">))
      response_text = CGI.unescapeHTML(response.body)
      expect(response_text).to include("Title can't be blank")
      expect(response_text).to include("Entry type is not included in the list")
    end

    it "redirects back to the profile for non-Turbo HTML fallback requests" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_timeline_entries_path(profile),
        params: { timeline_entry: { title: "Called after dinner", entry_type: "note", occurred_at: "2026-07-08T14:30" } }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(response).to have_http_status(:found)
    end
  end

  describe "GET /relationship_profiles/:relationship_profile_id/timeline_entries/new" do
    it "returns the matching Turbo frame for lazy inline creation" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      get new_relationship_profile_timeline_entry_path(profile, timeline_type: "gift"), headers: { "Turbo-Frame" => "new_timeline_entry" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(<turbo-frame id="new_timeline_entry">))
      expect(response.body).to include("Add timeline entry")
      expect(response.body).to include(%(<option selected="selected" value="gift">Gift</option>))
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/timeline_entries/:id" do
    it "updates a system timeline entry through Turbo while preserving system fields" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      entry = create(:timeline_entry, relationship_profile: profile, origin: "system", title: "Original")
      sign_in user

      patch relationship_profile_timeline_entry_path(profile, entry),
        params: { timeline_entry: { title: "Updated", entry_type: "note", origin: "manual" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Updated")
      expect(entry.reload).to have_attributes(title: "Updated", origin: "system")
    end

    it "does not update a source-backed timeline entry directly" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      recap = create(:conversation_recap, relationship_profile: profile, title: "Lunch recap")
      entry = create(:timeline_entry, relationship_profile: profile, entry_type: "conversation_recap", origin: "system", source_record: recap, title: "Lunch recap")
      sign_in user

      patch relationship_profile_timeline_entry_path(profile, entry),
        params: { timeline_entry: { title: "Tampered", entry_type: "note" } },
        as: :turbo_stream

      expect(response).to have_http_status(:forbidden)
      expect(entry.reload).to have_attributes(title: "Lunch recap", entry_type: "conversation_recap", source_record: recap)
    end
  end

  describe "DELETE /relationship_profiles/:relationship_profile_id/timeline_entries/:id" do
    it "deletes a timeline entry through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      entry = create(:timeline_entry, relationship_profile: profile)
      sign_in user

      expect do
        delete relationship_profile_timeline_entry_path(profile, entry), as: :turbo_stream
      end.to change(TimelineEntry, :count).by(-1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("No timeline entries match this view")
    end

    it "does not delete a source-backed timeline entry directly" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      recap = create(:conversation_recap, relationship_profile: profile)
      entry = create(:timeline_entry, relationship_profile: profile, entry_type: "conversation_recap", origin: "system", source_record: recap)
      sign_in user

      expect do
        delete relationship_profile_timeline_entry_path(profile, entry), as: :turbo_stream
      end.not_to change(TimelineEntry, :count)

      expect(response).to have_http_status(:forbidden)
      expect(entry.reload).to be_present
    end
  end
end
