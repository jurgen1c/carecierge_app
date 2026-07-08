require "cgi"
require "rails_helper"

RSpec.describe "Memory records", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "GET /relationship_profiles/:relationship_profile_id" do
    it "renders memory records with trust metadata and review cues" do
      user = create(:user)
      profile = create(:relationship_profile, user:, first_name: "Ana")
      create(
        :memory_record,
        relationship_profile: profile,
        title: "Prefers quiet birthday dinners",
        body: "Ana liked smaller birthday plans last year.",
        source: "ai_inferred",
        confidence: "low",
        status: "needs_review",
        stale_after: Date.new(2026, 7, 1)
      )
      sign_in user

      travel_to Time.zone.local(2026, 7, 8, 10, 0, 0) do
        get relationship_profile_path(profile)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Memory records")
      expect(response.body).to include("Prefers quiet birthday dinners")
      expect(response.body).to include("AI inferred")
      expect(response.body).to include("Low")
      expect(response.body).to include("Needs review")
      expect(response.body).to include("High-impact automation needs approval")
      expect(response.body).to include("Delete")
      expect(response.body).to include(%(href="#{new_relationship_profile_memory_record_path(profile)}"))
    end

    it "renders localized memory copy in Spanish" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      create(:memory_record, relationship_profile: profile, title: "Prefiere té", body: "El té verde fue bien recibido.")
      sign_in user

      I18n.with_locale(:es) do
        get relationship_profile_path(profile)
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Memorias")
      expect(response.body).to include("Agregar memoria")
      expect(response.body).not_to include("Memory records")
      expect(response.body).not_to include("Translation missing")
    end
  end

  describe "POST /relationship_profiles/:relationship_profile_id/memory_records" do
    it "creates a memory record through Turbo without leaving the profile page" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        post relationship_profile_memory_records_path(profile),
          params: {
            memory_record: {
              title: "Likes jasmine tea",
              body: "Said jasmine tea helps her unwind.",
              source: "user_confirmed",
              confidence: "confirmed",
              status: "active",
              stale_after: "2026-10-01"
            }
          },
          as: :turbo_stream
      end.to change(MemoryRecord, :count).by(1)

      record = profile.memory_records.reload.sole
      expect(record).to have_attributes(
        title: "Likes jasmine tea",
        body: "Said jasmine tea helps her unwind.",
        source: "user_confirmed",
        confidence: "confirmed",
        status: "active",
        stale_after: Date.new(2026, 10, 1)
      )
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="memory_records_section"))
      expect(response.body).to include("Likes jasmine tea")
    end

    it "does not create a memory record for another user's profile" do
      sign_in create(:user)
      profile = create(:relationship_profile)

      expect do
        post relationship_profile_memory_records_path(profile),
          params: { memory_record: { title: "Private", body: "Hidden" } },
          as: :turbo_stream
      end.not_to change(MemoryRecord, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "renders validation errors in the new frame" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      expect do
        post relationship_profile_memory_records_path(profile),
          params: { memory_record: { title: "", body: "", source: "unknown", confidence: "low", status: "active" } },
          as: :turbo_stream
      end.not_to change(MemoryRecord, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(<turbo-frame id="new_memory_record">))
      response_text = CGI.unescapeHTML(response.body)
      expect(response_text).to include("Title can't be blank")
      expect(response_text).to include("Source is not included in the list")
    end

    it "redirects back to the profile for non-Turbo HTML fallback requests" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      sign_in user

      post relationship_profile_memory_records_path(profile),
        params: { memory_record: { title: "Likes jasmine tea", body: "Confirmed during dinner.", source: "user_confirmed", confidence: "confirmed", status: "active" } }

      expect(response).to redirect_to(relationship_profile_path(profile))
      expect(response).to have_http_status(:found)
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/memory_records/:id" do
    it "updates the record and stores a revision when the memory body changes" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile, body: "Original memory")
      sign_in user

      expect do
        patch relationship_profile_memory_record_path(profile, record),
          params: { memory_record: { title: record.title, body: "Corrected memory", correction_note: "User clarified it." } },
          as: :turbo_stream
      end.to change(MemoryRevision, :count).by(1)

      revision = record.memory_revisions.sole
      expect(record.reload).to have_attributes(body: "Corrected memory", source: "user_corrected", status: "corrected")
      expect(revision).to have_attributes(
        user_id: user.id,
        previous_body: "Original memory",
        revised_body: "Corrected memory",
        note: "User clarified it."
      )
    end

    it "clears prior high-impact approval when the memory body is corrected" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile, body: "Original memory", high_impact_automation_approved_at: Time.current, reviewed_at: Time.current)
      sign_in user

      patch relationship_profile_memory_record_path(profile, record),
        params: { memory_record: { title: record.title, body: "Corrected memory" } },
        as: :turbo_stream

      expect(record.reload).to have_attributes(
        body: "Corrected memory",
        high_impact_automation_approved_at: nil,
        reviewed_at: nil
      )
      expect(record).to be_high_impact_automation_allowed
    end

    it "clears prior high-impact approval when trust metadata changes" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile, confidence: "confirmed", high_impact_automation_approved_at: Time.current, reviewed_at: Time.current)
      sign_in user

      patch relationship_profile_memory_record_path(profile, record),
        params: { memory_record: { title: record.title, body: record.body, confidence: "low" } },
        as: :turbo_stream

      expect(record.reload).to have_attributes(
        confidence: "low",
        high_impact_automation_approved_at: nil,
        reviewed_at: nil
      )
      expect(record).not_to be_high_impact_automation_allowed
    end

    it "updates metadata without storing a revision when the body is unchanged" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile, body: "Original memory", confidence: "medium")
      sign_in user

      expect do
        patch relationship_profile_memory_record_path(profile, record),
          params: { memory_record: { title: record.title, body: "Original memory", confidence: "high" } },
          as: :turbo_stream
      end.not_to change(MemoryRevision, :count)

      expect(record.reload).to have_attributes(body: "Original memory", confidence: "high", status: "active")
    end

    it "rolls back the record update when revision creation fails" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile, body: "Original memory", source: "user_confirmed", status: "active")
      revision_error = ActiveRecord::RecordInvalid.new(MemoryRevision.new)
      sign_in user

      allow_any_instance_of(MemoryRevision).to receive(:save!).and_raise(revision_error)

      expect do
        patch relationship_profile_memory_record_path(profile, record),
          params: { memory_record: { title: record.title, body: "Corrected memory", correction_note: "User clarified it." } },
          as: :turbo_stream
      end.not_to change(MemoryRevision, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("User clarified it.")
      expect(record.reload).to have_attributes(body: "Original memory", source: "user_confirmed", status: "active")
    end

    it "renders validation errors in the edit frame" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile)
      sign_in user

      patch relationship_profile_memory_record_path(profile, record),
        params: { memory_record: { title: "", body: "", source: "user_confirmed", confidence: "confirmed", status: "active" } },
        as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(%(<turbo-frame id="#{ActionView::RecordIdentifier.dom_id(record)}">))
      expect(CGI.unescapeHTML(response.body)).to include("Title can't be blank")
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/memory_records/:id/review" do
    it "marks the record reviewed with confirmed metadata" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile, status: "needs_review", confidence: "low")
      sign_in user

      patch review_relationship_profile_memory_record_path(profile, record), as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(record.reload).to have_attributes(status: "active", confidence: "confirmed")
      expect(record.reviewed_at).to be_present
      expect(record).not_to be_review_required
    end

    it "does not report success when the record cannot be reviewed" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile, status: "archived", confidence: "low", stale_after: Date.yesterday)
      sign_in user

      patch review_relationship_profile_memory_record_path(profile, record), as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Memory could not be marked reviewed.")
      expect(record.reload).to have_attributes(status: "archived", confidence: "low", stale_after: Date.yesterday)
    end

    it "handles review validation failures without reporting success" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile, status: "needs_review", confidence: "low")
      review_error = ActiveRecord::RecordInvalid.new(record)
      sign_in user

      allow_any_instance_of(MemoryRecord).to receive(:mark_reviewed!).and_raise(review_error)

      patch review_relationship_profile_memory_record_path(profile, record), as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Memory could not be marked reviewed.")
      expect(record.reload).to have_attributes(status: "needs_review", confidence: "low")
    end
  end

  describe "PATCH /relationship_profiles/:relationship_profile_id/memory_records/:id/approve_high_impact_automation" do
    it "approves a low-confidence memory for high-impact automation" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile, source: "ai_inferred", confidence: "low")
      sign_in user

      patch approve_high_impact_automation_relationship_profile_memory_record_path(profile, record), as: :turbo_stream

      expect(record.reload).to be_high_impact_automation_allowed
      expect(record.high_impact_automation_approved_at).to be_present
    end
  end

  describe "DELETE /relationship_profiles/:relationship_profile_id/memory_records/:id" do
    it "deletes a memory record through Turbo" do
      user = create(:user)
      profile = create(:relationship_profile, user:)
      record = create(:memory_record, relationship_profile: profile, title: "Old memory")
      sign_in user

      expect do
        delete relationship_profile_memory_record_path(profile, record), as: :turbo_stream
      end.to change(MemoryRecord, :count).by(-1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="memory_records_section"))
      expect(response.body).not_to include("Old memory")
    end
  end
end
