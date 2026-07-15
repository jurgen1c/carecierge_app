require "cgi"
require "rails_helper"

RSpec.describe "Mood notes", type: :request do
  describe "GET /relationship_profiles/:relationship_profile_id" do
    it "renders observation-first mood notes, follow-up guidance, and timeline linkage" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Ana")
      mood_note = create(
        :mood_note,
        relationship_profile: profile,
        category: "stressed",
        observation: "Seemed tense after the meeting.",
        supportive_action: "Send a gentle check-in.",
        follow_up_at: Time.zone.local(2026, 7, 14, 9, 0, 0)
      )
      create(:timeline_entry, relationship_profile: profile, source_record: mood_note, entry_type: "mood_note", origin: "system", title: mood_note.display_title, occurred_at: mood_note.observed_at)
      sign_in user

      get relationship_profile_path(profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mood notes")
      expect(response.body).to include("Record what you noticed, not a diagnosis")
      expect(response.body).to include("Seemed tense after the meeting.")
      expect(response.body).to include("Send a gentle check-in.")
      expect(response.body).to include("Follow up")
      expect(response.body).to include(%(href="#{new_relationship_profile_mood_note_path(profile)}"))
      expect(response.body).to include("Mood note")
    end

    it "renders Spanish copy without falling back to English" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:mood_note, relationship_profile: profile, observation: "Se notó tensión después del trabajo.")
      sign_in user

      I18n.with_locale(:es) do
        get relationship_profile_path(profile)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Notas de ánimo")
      expect(response.body).to include("Registra lo que notaste, no un diagnóstico")
      expect(response.body).to include("Estrés observado")
      expect(response.body).to include("Se notó tensión después del trabajo.")
      expect(response.body).not_to include("Mood notes")
      expect(response.body).not_to include("Translation missing")
    end

    it "queries mood notes once while rendering the profile" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create_list(:mood_note, 2, relationship_profile: profile)
      sign_in user

      queries = capture_sql { get relationship_profile_path(profile) }

      expect(response).to have_http_status(:ok)
      expect(queries.grep(/FROM "mood_notes"/).size).to eq(1)
    end
  end

  describe "POST /relationship_profiles/:relationship_profile_id/mood_notes" do
    it "creates a mood note and optional linked timeline entry through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        expect do
          expect do
            post relationship_profile_mood_notes_path(profile),
              params: {
                mood_note: {
                  category: "overwhelmed",
                  observation: "  Seemed overwhelmed after moving.  ",
                  observed_at: "2026-07-12T18:30",
                  supportive_action: "Offer to help with one practical task.",
                  follow_up_at: "2026-07-14T09:00",
                  timeline_visible: "1"
                }
              },
              as: :turbo_stream
          end.to change(MoodNote, :count).by(1)
        end.to change(TimelineEntry, :count).by(1)
      end.to change(Interaction, :count).by(1)

      mood_note = profile.mood_notes.reload.sole
      expect(mood_note).to have_attributes(
        category: "overwhelmed",
        observation: "Seemed overwhelmed after moving.",
        supportive_action: "Offer to help with one practical task.",
        observed_at: Time.zone.local(2026, 7, 12, 18, 30, 0),
        follow_up_at: Time.zone.local(2026, 7, 14, 9, 0, 0),
        timeline_visible: true
      )
      expect(profile.timeline_entries.reload.sole).to have_attributes(
        entry_type: "mood_note",
        origin: "system",
        title: mood_note.display_title,
        body: "Offer to help with one practical task.",
        occurred_at: mood_note.observed_at,
        source_record: mood_note
      )
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="mood_notes_section"))
      expect(response.body).to include(%(turbo-stream action="replace" target="timeline_entries_section"))
    end

    it "omits the timeline row when timeline visibility is not selected" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        expect do
          post relationship_profile_mood_notes_path(profile),
            params: { mood_note: { category: "proud", observation: "Seemed proud.", timeline_visible: "0" } },
            as: :turbo_stream
        end.to change(MoodNote, :count).by(1)
      end.not_to change(TimelineEntry, :count)

      expect(profile.mood_notes.reload.sole.timeline_visible).to be(false)
    end

    it "does not create a note for another user's relationship" do
      sign_in create(:user)
      profile = create(:relationship_profile)

      expect do
        post relationship_profile_mood_notes_path(profile),
          params: { mood_note: { category: "sad", observation: "Private observation" } },
          as: :turbo_stream
      end.not_to change(MoodNote, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "renders validation errors in the new frame" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_mood_notes_path(profile),
        params: { mood_note: { category: "diagnosed", observation: "" } },
        as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(<turbo-frame id="new_mood_note">))
      response_text = CGI.unescapeHTML(response.body)
      expect(response_text).to include("Observation can't be blank")
      expect(response_text).to include("Category is not included in the list")
    end

    it "surfaces a future observation error on the source form" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      Timecop.freeze(Time.zone.local(2026, 7, 14, 12)) do
        expect do
          post relationship_profile_mood_notes_path(profile),
            params: { mood_note: { category: "excited", observation: "Not observed yet.", observed_at: "2026-07-14T12:01" } },
            as: :turbo_stream
        end.not_to change(MoodNote, :count)
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(CGI.unescapeHTML(response.body)).to include("Observed time can't be in the future")
    end

    it "redirects back to the profile for non-Turbo HTML fallback requests" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_mood_notes_path(profile, timeline_type: "gift"),
        params: { mood_note: { category: "excited", observation: "Seemed excited.", timeline_visible: "1" } }

      expect(response).to redirect_to(relationship_profile_path(profile, timeline_type: "gift"))
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/mood_notes/:id" do
    it "removes and recreates linked timeline entries as timeline visibility changes" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      mood_note = create(:mood_note, relationship_profile: profile, timeline_visible: true)
      create(:timeline_entry, relationship_profile: profile, source_record: mood_note, entry_type: "mood_note", origin: "system", title: mood_note.display_title, occurred_at: mood_note.observed_at)
      sign_in user

      expect do
        patch relationship_profile_mood_note_path(profile, mood_note),
          params: { mood_note: { timeline_visible: "0" } },
          as: :turbo_stream
      end.to change(TimelineEntry, :count).by(-1)

      expect do
        patch relationship_profile_mood_note_path(profile, mood_note),
          params: { mood_note: { observation: "Seemed more at ease.", timeline_visible: "1" } },
          as: :turbo_stream
      end.to change(TimelineEntry, :count).by(1)

      expect(mood_note.reload.observation).to eq("Seemed more at ease.")
      expect(mood_note.timeline_entry).to have_attributes(title: "Seemed more at ease.", entry_type: "mood_note")
      expect(mood_note.interaction).to have_attributes(interaction_type: "mood_note", occurred_at: mood_note.observed_at)
    end
  end

  describe "DELETE /relationship_profiles/:relationship_profile_id/mood_notes/:id" do
    it "deletes the mood note and its linked timeline entry through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      mood_note = create(:mood_note, relationship_profile: profile)
      create(:timeline_entry, relationship_profile: profile, source_record: mood_note, entry_type: "mood_note", origin: "system", title: mood_note.display_title, occurred_at: mood_note.observed_at)
      create(:interaction, :derived_from_mood_note, relationship_profile: profile, source: mood_note)
      sign_in user

      expect do
        expect do
          expect do
            delete relationship_profile_mood_note_path(profile, mood_note), as: :turbo_stream
          end.to change(MoodNote, :count).by(-1)
        end.to change(TimelineEntry, :count).by(-1)
      end.to change(Interaction, :count).by(-1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("No mood notes yet")
    end
  end

  def capture_sql
    queries = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:cached] || payload[:name] == "SCHEMA"

      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
    queries
  end
end
