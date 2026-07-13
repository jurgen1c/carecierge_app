require "cgi"
require "rails_helper"

RSpec.describe "Conversation recaps", type: :request do
  describe "GET /relationship_profiles/:relationship_profile_id" do
    it "renders recaps with extraction guardrails and timeline linkage" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Ana")
      recap = create(
        :conversation_recap,
        relationship_profile: profile,
        title: "Lunch with David",
        body: "David is thinking about changing jobs.",
        extraction_status: "requested",
        extraction_requested_at: Time.zone.local(2026, 7, 8, 12, 0, 0)
      )
      create(:timeline_entry, relationship_profile: profile, entry_type: "conversation_recap", origin: "system", source_record: recap, title: recap.title, occurred_at: recap.occurred_at)
      sign_in user

      get relationship_profile_path(profile)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Conversation recaps")
      expect(response.body).to include("Lunch with David")
      expect(response.body).to include("Extraction requested")
      expect(response.body).to include("No memory changes happen until you approve extracted suggestions.")
      expect(response.body).to include(%(href="#{new_relationship_profile_conversation_recap_path(profile)}"))
      expect(response.body).to include("Conversation recap")
      expect(response.body).to include("Conversation recap: Lunch with David")
    end

    it "renders localized recap copy in Spanish" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      recap = create(:conversation_recap, relationship_profile: profile, title: "Almuerzo", body: "Hablamos del cambio de trabajo.")
      create(:timeline_entry, relationship_profile: profile, entry_type: "conversation_recap", origin: "system", source_record: recap, title: recap.title, occurred_at: recap.occurred_at)
      sign_in user

      I18n.with_locale(:es) do
        get relationship_profile_path(profile)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Resúmenes de conversaciones")
      expect(response.body).to include("Agregar resumen")
      expect(response.body).to include("Resumen de conversación: Almuerzo")
      expect(response.body).not_to include("Conversation recaps")
      expect(response.body).not_to include("Conversation recap: Almuerzo")
      expect(response.body).not_to include("Translation missing")
    end

    it "preserves the active timeline filter in recap actions" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      recap = create(:conversation_recap, relationship_profile: profile)
      sign_in user

      get relationship_profile_path(profile, timeline_type: "gift")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(href="#{new_relationship_profile_conversation_recap_path(profile, timeline_type: "gift")}"))
      expect(response.body).to include(%(href="#{edit_relationship_profile_conversation_recap_path(profile, recap, timeline_type: "gift")}"))
      expect(response.body).to include(%(action="#{relationship_profile_conversation_recap_path(profile, recap, timeline_type: "gift")}"))
    end

    it "queries conversation recaps once while rendering the profile" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create_list(:conversation_recap, 2, relationship_profile: profile)
      sign_in user

      queries = capture_sql { get relationship_profile_path(profile) }
      recap_queries = queries.grep(/FROM "conversation_recaps"/)

      expect(response).to have_http_status(:ok)
      expect(recap_queries.size).to eq(1)
    end
  end

  describe "POST /relationship_profiles/:relationship_profile_id/conversation_recaps" do
    it "creates a text recap and linked system timeline entry through Turbo without mutating memory records" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        expect do
          expect do
            post relationship_profile_conversation_recaps_path(profile),
              params: {
                conversation_recap: {
                  title: "Lunch with David",
                  body: "He is thinking about changing jobs.",
                  occurred_at: "2026-07-08T12:30",
                  capture_source: "voice_transcript",
                  transcript: "Raw transcript text",
                  request_memory_extraction: "1",
                  extraction_status: "approved",
                  extraction_approved_at: "2026-07-08T12:45"
                }
              },
              as: :turbo_stream
          end.to change(ConversationRecap, :count).by(1)
        end.to change(TimelineEntry, :count).by(1)
      end.not_to change(MemoryRecord, :count)

      recap = profile.conversation_recaps.reload.sole
      entry = profile.timeline_entries.reload.sole
      expect(recap).to have_attributes(
        title: "Lunch with David",
        body: "He is thinking about changing jobs.",
        occurred_at: Time.zone.local(2026, 7, 8, 12, 30, 0),
        capture_source: "voice_transcript",
        transcript: "Raw transcript text",
        extraction_status: "requested",
        extraction_approved_at: nil
      )
      expect(recap.extraction_requested_at).to be_present
      expect(entry).to have_attributes(
        entry_type: "conversation_recap",
        origin: "system",
        title: "Lunch with David",
        body: "He is thinking about changing jobs.",
        occurred_at: Time.zone.local(2026, 7, 8, 12, 30, 0),
        source_record: recap
      )
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="conversation_recaps_section"))
      expect(response.body).to include(%(turbo-stream action="replace" target="timeline_entries_section"))
      expect(response.body).to include("Lunch with David")
    end

    it "does not create a recap for another user's profile" do
      sign_in create(:user)
      profile = create(:relationship_profile)

      expect do
        post relationship_profile_conversation_recaps_path(profile),
          params: { conversation_recap: { title: "Private", body: "Hidden", occurred_at: "2026-07-08T12:30" } },
          as: :turbo_stream
      end.not_to change(ConversationRecap, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "renders validation errors in the new frame" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        post relationship_profile_conversation_recaps_path(profile),
          params: { conversation_recap: { title: "", body: "", capture_source: "unknown" } },
          as: :turbo_stream
      end.not_to change(ConversationRecap, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(<turbo-frame id="new_conversation_recap">))
      response_text = CGI.unescapeHTML(response.body)
      expect(response_text).to include("Title can't be blank")
      expect(response_text).to include("Recap can't be blank")
      expect(response_text).to include("Capture source is not included in the list")
    end

    it "preserves a requested extraction when validation fails" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_conversation_recaps_path(profile),
        params: { conversation_recap: { title: "", body: "", request_memory_extraction: "1" } },
        as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      response_text = CGI.unescapeHTML(response.body)
      expect(response_text).to include("Suggest memories for my approval")
      expect(response_text).to match(/type="checkbox"[^>]+value="1"[^>]+checked="checked"[^>]+name="conversation_recap\[request_memory_extraction\]"/)
    end

    it "redirects back to the profile for non-Turbo HTML fallback requests" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_conversation_recaps_path(profile, timeline_type: "gift"),
        params: { conversation_recap: { title: "Lunch", body: "Talked about work.", occurred_at: "2026-07-08T12:30" } }

      expect(response).to redirect_to(relationship_profile_path(profile, timeline_type: "gift"))
      expect(response).to have_http_status(:found)
    end

    it "refreshes the timeline with the active filter after creating a recap" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_conversation_recaps_path(profile, timeline_type: "gift"),
        params: {
          conversation_recap: {
            title: "Lunch with David",
            body: "He is thinking about changing jobs.",
            occurred_at: "2026-07-08T12:30"
          }
        },
        as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(turbo-stream action="replace" target="timeline_entries_section"))
      expect(response.body).to include("No timeline entries match this view")
      expect(response.body).not_to include("Conversation recap: Lunch with David")
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/conversation_recaps/:id" do
    it "renders an edit form cancel link that preserves the active timeline filter" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      recap = create(:conversation_recap, relationship_profile: profile)
      sign_in user

      get edit_relationship_profile_conversation_recap_path(profile, recap, timeline_type: "gift")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(href="#{relationship_profile_path(profile, timeline_type: "gift", anchor: ActionView::RecordIdentifier.dom_id(recap, :row))}"))
    end

    it "offers extraction on edit while the recap has not requested it" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      recap = create(:conversation_recap, relationship_profile: profile, extraction_status: "not_requested")
      sign_in user

      get edit_relationship_profile_conversation_recap_path(profile, recap)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(name="conversation_recap[request_memory_extraction]"))
      expect(response.body).to include("Suggest memories for my approval")
    end

    it "requests extraction during a later edit without mutating memory records" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      recap = create(:conversation_recap, relationship_profile: profile, extraction_status: "not_requested")
      sign_in user

      expect do
        patch relationship_profile_conversation_recap_path(profile, recap),
          params: { conversation_recap: { request_memory_extraction: "1" } },
          as: :turbo_stream
      end.not_to change(MemoryRecord, :count)

      expect(response).to have_http_status(:ok)
      expect(recap.reload.extraction_status).to eq("requested")
      expect(recap.extraction_requested_at).to be_present
    end

    it "updates the recap and keeps the linked timeline entry in sync" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      recap = create(:conversation_recap, relationship_profile: profile, title: "Original", body: "Original body")
      timeline_entry = create(:timeline_entry, relationship_profile: profile, entry_type: "conversation_recap", origin: "system", source_record: recap, title: "Original", body: "Original body")
      sign_in user

      patch relationship_profile_conversation_recap_path(profile, recap),
        params: { conversation_recap: { title: "Updated recap", body: "Updated body", occurred_at: "2026-07-08T13:00" } },
        as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("Updated recap")
      expect(recap.reload).to have_attributes(title: "Updated recap", body: "Updated body")
      expect(timeline_entry.reload).to have_attributes(title: "Updated recap", body: "Updated body", occurred_at: Time.zone.local(2026, 7, 8, 13, 0, 0))
    end
  end

  describe "DELETE /relationship_profiles/:relationship_profile_id/conversation_recaps/:id" do
    it "deletes the recap and linked timeline entry through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      recap = create(:conversation_recap, relationship_profile: profile)
      create(:timeline_entry, relationship_profile: profile, entry_type: "conversation_recap", origin: "system", source_record: recap)
      sign_in user

      expect do
        expect do
          delete relationship_profile_conversation_recap_path(profile, recap), as: :turbo_stream
        end.to change(ConversationRecap, :count).by(-1)
      end.to change(TimelineEntry, :count).by(-1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("No conversation recaps yet")
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
