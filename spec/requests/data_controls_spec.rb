require "rails_helper"

RSpec.describe "Data controls", type: :request do
  it "exports decrypted AI workspaces without internal generation fences" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    briefing = create(:relationship_briefing, user:, relationship_profile: profile, status: "saved")
    recommendation = create(:gift_recommendation, user:, relationship_profile: profile, status: "saved")
    sign_in user

    post data_exports_path, params: { data_export: { format: "json", scope: "account" } }

    payload = JSON.parse(response.body)
    exported_profile = payload.fetch("relationship_profiles").sole
    expect(exported_profile).not_to have_key("briefing_generation_version")
    expect(exported_profile).not_to have_key("gift_recommendation_generation_version")
    expect(exported_profile.fetch("relationship_briefings").sole).to include(
      "interaction_context" => briefing.interaction_context,
      "sections" => briefing.sections
    )
    expect(exported_profile.fetch("gift_recommendations").sole).to include(
      "title" => recommendation.title,
      "rationale" => recommendation.rationale,
      "source_context" => recommendation.source_context
    )
  end

  it "exports event plans with decrypted tasks and source provenance without internal fences" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    plan = create(
      :event_plan,
      user:,
      relationship_profile: profile,
      title: "Maya's birthday dinner",
      source_context: [ { "id" => "memory:favorite-tea", "label" => "Favorite tea" } ]
    )
    task = create(
      :plan_task,
      event_plan: plan,
      origin: "ai",
      title: "Ask about tea service",
      source_context: [
        {
          "id" => "memory:favorite-tea",
          "label" => "Favorite tea",
          "certainty" => "confirmed",
          "sensitive" => false
        }
      ]
    )
    backup_plan = create(:backup_plan, user:, event_plan: plan)
    backup_option = create(:backup_option, backup_plan:, title: "Move dinner indoors")
    sign_in user

    post data_exports_path, params: { data_export: { format: "json", scope: "account" } }

    exported_plan = response.parsed_body.dig("relationship_profiles", 0, "event_plans", 0)
    expect(exported_plan).to include(
      "id" => plan.id,
      "title" => "Maya's birthday dinner",
      "source_context" => plan.source_context
    )
    expect(exported_plan).not_to have_key("user_id")
    expect(exported_plan).not_to have_key("relationship_profile_id")
    expect(exported_plan).not_to have_key("generation_version")
    expect(exported_plan).not_to have_key("lock_version")
    expect(exported_plan.fetch("plan_tasks").sole).to include(
      "id" => task.id,
      "title" => "Ask about tea service",
      "source_context" => task.source_context
    )
    expect(exported_plan.fetch("plan_tasks").sole).not_to have_key("event_plan_id")
    expect(exported_plan.fetch("plan_tasks").sole).not_to have_key("lock_version")
    exported_backup = exported_plan.fetch("backup_plans").sole
    expect(exported_backup).to include(
      "id" => backup_plan.id,
      "scenario" => "weather",
      "source_context" => backup_plan.source_context
    )
    expect(exported_backup).not_to have_key("event_plan_generation_version")
    expect(exported_backup.fetch("backup_options").sole).to include(
      "id" => backup_option.id,
      "title" => "Move dinner indoors",
      "source_context" => backup_option.source_context
    )
  end

  it "exports saved vendors with provenance and plan attachments" do
    user = create(:user)
    plan = create(:event_plan, user:)
    vendor = create(
      :vendor,
      user:,
      name: "Casa Verde",
      source_kind: "external",
      source_name: "Vendor website",
      source_url: "https://example.com/casa-verde",
      fit_notes: "Quiet dining room."
    )
    create(:event_plan_vendor, event_plan: plan, vendor:)
    sign_in user

    post data_exports_path, params: { data_export: { format: "json", scope: "account" } }

    exported_vendor = response.parsed_body.fetch("vendors").sole
    expect(exported_vendor).to include(
      "id" => vendor.id,
      "name" => "Casa Verde",
      "source_kind" => "external",
      "source_name" => "Vendor website",
      "source_url" => "https://example.com/casa-verde",
      "fit_notes" => "Quiet dining room.",
      "event_plan_ids" => [ plan.id ]
    )
    expect(exported_vendor).not_to have_key("user_id")
    expect(response.parsed_body.dig("relationship_profiles", 0, "event_plans", 0, "vendors", 0)).to include(
      "id" => vendor.id,
      "event_plan_ids" => [ plan.id ]
    )
  end

  it "limits vendor attachment identifiers to the selected relationship profile" do
    user = create(:user)
    selected_profile = create(:relationship_profile, user:)
    other_profile = create(:relationship_profile, user:)
    selected_plan = create(:event_plan, user:, relationship_profile: selected_profile)
    other_plan = create(:event_plan, user:, relationship_profile: other_profile)
    vendor = create(:vendor, user:)
    create(:event_plan_vendor, event_plan: selected_plan, vendor:)
    create(:event_plan_vendor, event_plan: other_plan, vendor:)
    sign_in user

    post data_exports_path, params: {
      data_export: { format: "json", scope: "relationship_profile", relationship_profile_id: selected_profile.id }
    }

    exported_vendor = response.parsed_body.dig("relationship_profiles", 0, "event_plans", 0, "vendors", 0)
    expect(exported_vendor.fetch("event_plan_ids")).to eq([ selected_plan.id ])
    expect(response.body).not_to include(other_plan.id)
  end

  let(:password) { "careful-password" }
  let(:user) { create(:user, email: "owner@example.com", password:) }
  let(:profile) { create(:relationship_profile, user:, first_name: "Maya", last_name: "Rivera") }

  describe "GET /data_controls" do
    it "requires authentication" do
      get data_control_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows localized export formats and destructive controls" do
      profile
      sign_in user

      I18n.with_locale(:es) { get data_control_path }

      expect(response).to have_http_status(:ok)
      expect(response.headers.fetch("Cache-Control")).to include("no-store")
      expect(response.body).to include(I18n.t("data_controls.show.heading", locale: :es))
      expect(response.body).to include("JSON", "CSV", "PDF", "Calendario")
      expect(response.body).to include(profile.display_name)
      expect(response.body).to include(I18n.t("data_controls.show.delete_account.title", locale: :es))
    end

    it "discloses every AI workspace deletion in English and Spanish" do
      sign_in user

      I18n.with_locale(:en) { get data_control_path }
      expect(response.body).to include("social-context interpretations", "gift recommendations", "event-plan suggestions")

      I18n.with_locale(:es) { get data_control_path }
      expect(response.body).to include(
        "interpretaciones de contexto social",
        "recomendaciones de regalos",
        "sugerencias de planes de eventos"
      )
    end

    it "gives OAuth users an explicit password setup path before account deletion" do
      user.update!(provider: "google_oauth2", uid: "google-owner")
      sign_in user

      get data_control_path

      expect(response.body).to include(new_user_password_path)
      expect(response.body).to include(I18n.t("data_controls.show.delete_account.set_password_action"))
    end
  end

  describe "POST /data_exports" do
    before do
      create(:timeline_entry, relationship_profile: profile, title: "First meeting")
      create(:important_date, relationship_profile: profile, title: "Birthday")
      create(:memory_record, relationship_profile: profile, title: "Favorite tea", source: "ai_inferred")
      sign_in user
    end

    it "exports all owned account data as JSON and records privacy-minimized evidence" do
      recap = create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review")
      extracted_memory = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap, category: "boundary", confidence: "medium")
      approval_request = create(:approval_request, user:, subject: extracted_memory)
      approval_request.approval_decisions.create!(user:, decision: "defer", occurred_at: Time.current)
      saved_at = Time.zone.local(2026, 8, 19, 9)
      create(:suggestion_feedback, user:, relationship_profile: profile, fingerprint: "saved-gesture", saved_at:)

      post data_exports_path, params: { data_export: { scope: "account", format: "json" } }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(response.headers.fetch("Cache-Control")).to include("no-store")
      expect(response.parsed_body.dig("account", "email")).to eq(user.email)
      expect(response.parsed_body.dig("relationship_profiles", 0, "timeline_entries", 0, "title")).to eq("First meeting")
      expect(response.parsed_body.dig("relationship_profiles", 0, "important_dates", 0, "title")).to eq("Birthday")
      expect(response.parsed_body.dig("relationship_profiles", 0, "memory_records", 0, "source")).to eq("ai_inferred")
      expect(response.parsed_body.dig("relationship_profiles", 0, "extracted_memories", 0)).to include(
        "category" => "boundary",
        "confidence" => "medium",
        "status" => "pending"
      )
      expect(response.parsed_body.dig("relationship_profiles", 0, "suggestion_feedbacks", 0)).to include(
        "fingerprint" => "saved-gesture",
        "saved_at" => saved_at.as_json
      )
      expect(response.parsed_body.dig("approval_requests", 0)).to include(
        "kind" => "extracted_memory",
        "status" => "pending",
        "subject_type" => "ExtractedMemory"
      )
      expect(response.parsed_body.dig("approval_requests", 0, "approval_decisions", 0, "decision")).to eq("defer")
      expect(user.audit_events.reload.last).to have_attributes(
        action: "data_export.requested",
        metadata: { "request_kind" => "account_json", "result" => "completed" }
      )
      expect(user.audit_events.last.to_json).not_to include("Maya", "Favorite tea")
    end

    it "includes uploaded conversation recordings in portable exports" do
      recap = create(:conversation_recap, relationship_profile: profile)
      recap.audio_recording.attach(
        io: StringIO.new("portable voice note"),
        filename: "voice-note.webm",
        content_type: "audio/webm"
      )

      post data_exports_path, params: { data_export: { scope: "account", format: "json" } }

      recording = response.parsed_body.dig("relationship_profiles", 0, "conversation_recaps", 0, "audio_recording")
      expect(recording).to include(
        "filename" => "voice-note.webm",
        "content_type" => "audio/webm",
        "byte_size" => 19,
        "encoding" => "base64",
        "data" => Base64.strict_encode64("portable voice note")
      )
    end

    it "includes user-provided social context and uploaded screenshots in portable exports" do
      blob = create_social_context_image_blob(user:, filename: "social-context.png", payload: "portable screenshot")
      create(
        :social_context_note,
        relationship_profile: profile,
        body: "<p>Bookshop post</p>#{ActionText::Attachment.from_attachable(blob).to_html}",
        allow_suggestions: true
      )

      post data_exports_path, params: { data_export: { scope: "account", format: "json" } }

      exported = response.parsed_body.dig("relationship_profiles", 0, "social_context_notes", 0)
      expect(exported).to include("body" => include("Bookshop post"), "allow_suggestions" => true)
      expect(exported).not_to have_key("lock_version")
      expect(exported.fetch("uploaded_images").sole).to include(
        "filename" => "social-context.png",
        "content_type" => "image/png",
        "encoding" => "base64",
        "data" => Base64.strict_encode64(social_context_png_bytes("portable screenshot"))
      )
    end

    it "includes message drafts and their immutable revision history" do
      draft = create(
        :message_draft,
        user:,
        relationship_profile: profile,
        draft_type: "birthday",
        tone: "warm",
        situation: "Maya shared a birthday post.",
        response_length: "short",
        formality: "casual"
      )
      create(:draft_revision, message_draft: draft, position: 1, origin: "generated", content: "Happy birthday, Maya!")
      create(:draft_revision, message_draft: draft, position: 2, origin: "edited", content: "Have a wonderful birthday, Maya!")

      post data_exports_path, params: { data_export: { scope: "account", format: "json" } }

      exported_draft = response.parsed_body.dig("relationship_profiles", 0, "message_draft")
      expect(exported_draft).to include(
        "draft_type" => "birthday",
        "tone" => "warm",
        "situation" => "Maya shared a birthday post.",
        "response_length" => "short",
        "formality" => "casual"
      )
      expect(exported_draft.fetch("draft_revisions").pluck("position", "origin", "content")).to contain_exactly(
        [ 1, "generated", "Happy birthday, Maya!" ],
        [ 2, "edited", "Have a wonderful birthday, Maya!" ]
      )
      expect(exported_draft).not_to have_key("user_id")
    end

    it "normalizes late legacy message-draft tone values in portable exports" do
      create(
        :message_draft,
        user:,
        relationship_profile: profile,
        tone: "formal",
        formality: "balanced"
      )

      post data_exports_path, params: { data_export: { scope: "account", format: "json" } }

      exported_draft = response.parsed_body.dig("relationship_profiles", 0, "message_draft")
      expect(exported_draft).to include("tone" => "warm", "formality" => "formal")
    end

    it "excludes the internal message-draft generation fence from portable profile data" do
      profile.update!(message_draft_generation_version: 7)

      post data_exports_path, params: { data_export: { scope: "account", format: "json" } }

      exported_profile = response.parsed_body.fetch("relationship_profiles").sole
      expect(exported_profile).not_to have_key("message_draft_generation_version")
    end

    it "includes privacy-safe account history, notifications, and reminder delivery evidence" do
      vault_event = create(:vault_access_event, user:, relationship_profile: profile, event_type: "viewed")
      reminder = create(:reminder, user:, relationship_profile: profile)
      delivery = create(
        :reminder_delivery,
        reminder:,
        status: "failed",
        lease_token: SecureRandom.uuid,
        error_message: "private transport failure"
      )
      ReminderInAppNotifier.with(record: reminder).deliver(user)
      notification = user.notifications.last

      post data_exports_path, params: { data_export: { scope: "account", format: "json" } }

      exported_vault_event = response.parsed_body.fetch("vault_access_events").sole
      expect(exported_vault_event).to include("id" => vault_event.id, "event_type" => "viewed")
      expect(exported_vault_event).not_to have_key("user_id")

      exported_notification = response.parsed_body.fetch("notifications").sole
      expect(exported_notification).to include(
        "id" => notification.id,
        "event_id" => notification.event_id,
        "type" => notification.type
      )
      expect(exported_notification).not_to have_key("recipient_id")
      expect(exported_notification).not_to have_key("recipient_type")

      exported_reminder = response.parsed_body.fetch("reminders").find { |record| record.fetch("id") == reminder.id }
      exported_delivery = exported_reminder.fetch("reminder_deliveries").sole
      expect(exported_delivery).to include(
        "id" => delivery.id,
        "channel" => delivery.channel,
        "status" => "failed"
      )
      expect(exported_delivery).not_to have_key("lease_token")
      expect(exported_delivery).not_to have_key("error_message")
    end

    it "includes feed-only dismissal and snooze state in account exports" do
      state = create(:feed_item_state, user:, item_key: "reminder:owned")

      post data_exports_path, params: { data_export: { scope: "account", format: "json" } }

      expect(response.parsed_body.fetch("feed_item_states").sole).to include(
        "id" => state.id,
        "item_key" => "reminder:owned",
        "dismissed_at" => state.dismissed_at.iso8601(3)
      )
      expect(response.parsed_body.fetch("feed_item_states").sole).not_to have_key("user_id")
    end

    it "exports only an owned relationship profile" do
      hidden_profile = create(:relationship_profile, first_name: "Hidden")
      selected_request = create(
        :approval_request,
        user:,
        subject: create(:memory_record, relationship_profile: profile),
        kind: "memory_record",
        action_key: "approve_high_impact_memory"
      )
      hidden_request = create(
        :approval_request,
        user:,
        subject: create(:memory_record, relationship_profile: create(:relationship_profile, user:)),
        kind: "memory_record",
        action_key: "approve_high_impact_memory"
      )

      post data_exports_path, params: {
        data_export: { scope: "relationship_profile", relationship_profile_id: profile.id, format: "json" }
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("relationship_profiles").pluck("id")).to eq([ profile.id ])
      expect(response.parsed_body.fetch("approval_requests").pluck("id")).to eq([ selected_request.id ])
      expect(response.body).not_to include(hidden_profile.id)
      expect(response.body).not_to include(hidden_request.id)
    end

    it "preserves profile tag, group, and notification-preference joins" do
      tag = create(:relationship_tag, user:, name: "Family")
      group = create(:relationship_group, user:, name: "Inner circle")
      create(:relationship_tagging, relationship_profile: profile, relationship_tag: tag)
      create(:relationship_group_membership, relationship_profile: profile, relationship_group: group)
      preference = create(:notification_preference, user:)
      create(:relationship_notification_preference, notification_preference: preference, relationship_profile: profile)

      post data_exports_path, params: { data_export: { scope: "account", format: "json" } }

      exported_profile = response.parsed_body.fetch("relationship_profiles").sole
      expect(exported_profile.fetch("relationship_taggings").sole.fetch("relationship_tag_id")).to eq(tag.id)
      expect(exported_profile.fetch("relationship_group_memberships").sole.fetch("relationship_group_id")).to eq(group.id)
      expect(exported_profile.fetch("relationship_notification_preference")).to include(
        "notification_preference_id" => preference.id,
        "mode" => "muted"
      )
    end

    it "fails closed for another user's relationship profile" do
      hidden_profile = create(:relationship_profile)

      post data_exports_path, params: {
        data_export: { scope: "relationship_profile", relationship_profile_id: hidden_profile.id, format: "json" }
      }

      expect(response).to have_http_status(:not_found)
      expect(user.audit_events).to be_empty
    end

    it "omits protected vault payloads unless the password is re-entered" do
      memory = create(:memory_record, relationship_profile: profile, title: "Private plan", body: "Meet at noon")
      item = PrivacyVault::Protect.call(actor: user, protectable: memory)

      post data_exports_path, params: {
        data_export: { scope: "relationship_profile", relationship_profile_id: profile.id, format: "json", include_sensitive: "1" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include("Meet at noon")

      post data_exports_path, params: {
        data_export: {
          scope: "relationship_profile",
          relationship_profile_id: profile.id,
          format: "json",
          include_sensitive: "1",
          current_password: password
        }
      }

      expect(response).to have_http_status(:ok)
      protected_item = response.parsed_body.dig("relationship_profiles", 0, "privacy_vault_items", 0)
      expect(protected_item).to include("id" => item.id, "payload" => hash_including("body" => "Meet at noon"))
    end

    it "supports CSV, PDF summary, and calendar exports" do
      allow(FerrumPdf).to receive(:render_pdf).and_return("%PDF-1.7 test")

      post data_exports_path, params: { data_export: { scope: "account", format: "csv" } }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/csv")
      expect(response.body).to include("relationship_profiles")

      post data_exports_path, params: { data_export: { scope: "account", format: "pdf" } }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.body).to start_with("%PDF")

      post data_exports_path, params: { data_export: { scope: "account", format: "ics" } }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/calendar")
      expect(response.body).to include("BEGIN:VCALENDAR", "SUMMARY:Birthday")
    end

    it "uses a trusted PDF origin and localized relationship labels" do
      rendered_html = nil
      localized_label = I18n.with_locale(:es) { profile.relationship_type_label }
      allow(FerrumPdf).to receive(:render_pdf) do |html:, display_url:, **|
        rendered_html = html
        expect(display_url).to eq("https://example.com")
        "%PDF-1.7 test"
      end

      I18n.with_locale(:es) do
        post data_exports_path,
          params: { data_export: { scope: "account", format: "pdf" } },
          headers: { "HOST" => "attacker.example", "X-Forwarded-Host" => "attacker.example" }
      end

      expect(response).to have_http_status(:ok)
      expect(rendered_html).to include(localized_label)
      expect(rendered_html).not_to include(profile.type.demodulize.humanize)
    end

    it "skips the full snapshot for calendar-only exports" do
      expect(DataExports::Snapshot).not_to receive(:new)

      post data_exports_path, params: { data_export: { scope: "account", format: "ics" } }

      expect(response).to have_http_status(:ok)
    end

    it "neutralizes formula-leading CSV values" do
      profile.update!(first_name: "=HYPERLINK(\"https://example.test\")")

      post data_exports_path, params: { data_export: { scope: "account", format: "csv" } }

      expect(response.body).to include(%q("'=HYPERLINK(""https://example.test"")"))
    end

    it "preserves clamped recurring dates in calendar exports" do
      create(
        :important_date,
        relationship_profile: profile,
        title: "Month end",
        starts_on: Date.new(2026, 1, 31),
        recurrence: "monthly"
      )

      post data_exports_path, params: { data_export: { scope: "account", format: "ics" } }

      expect(response.body).to include("RDATE;VALUE=DATE:")
      expect(response.body.delete("\r\n ")).to include("20260228", "20260331", "20260430")
    end
  end

  describe "POST /data_deletions" do
    before do
      sign_in user
    end

    it "deletes only AI-generated memory and timeline data after explicit confirmation" do
      ai_memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred")
      kept_memory = create(:memory_record, relationship_profile: profile, source: "user_confirmed")
      recap = create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review")
      proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap)
      ai_timeline = create(:timeline_entry, relationship_profile: profile, entry_type: "ai_extraction", origin: "system")
      manual_ai_timeline = create(:timeline_entry, relationship_profile: profile, entry_type: "ai_extraction", origin: "manual")
      kept_timeline = create(:timeline_entry, relationship_profile: profile, entry_type: "note", origin: "manual")

      post data_deletions_path, params: { data_deletion: { kind: "ai_generated", confirmation: user.email } }

      expect(response).to redirect_to(data_control_path)
      expect(MemoryRecord.exists?(ai_memory.id)).to be(false)
      expect(ExtractedMemory.exists?(proposal.id)).to be(false)
      expect(recap.reload).to have_attributes(extraction_status: "not_requested", extraction_requested_at: nil)
      expect(TimelineEntry.exists?(ai_timeline.id)).to be(false)
      expect(MemoryRecord.exists?(kept_memory.id)).to be(true)
      expect(TimelineEntry.exists?(manual_ai_timeline.id)).to be(true)
      expect(TimelineEntry.exists?(kept_timeline.id)).to be(true)
      expect(user.deletion_requests.last).to have_attributes(request_kind: "ai_generated", status: "completed")
      expect(user.audit_events.last).to have_attributes(
        action: "data_deletion.requested",
        metadata: { "request_kind" => "ai_generated", "result" => "completed" }
      )
    end

    it "cancels owned extraction requests even when they have not produced proposals" do
      requested_recap = create(
        :conversation_recap,
        relationship_profile: profile,
        extraction_status: "requested",
        extraction_requested_at: 1.minute.ago
      )
      processing_recap = create(
        :conversation_recap,
        relationship_profile: profile,
        extraction_status: "processing",
        extraction_requested_at: 2.minutes.ago,
        extraction_started_at: 1.minute.ago
      )

      post data_deletions_path, params: { data_deletion: { kind: "ai_generated", confirmation: user.email } }

      expect(requested_recap.reload).to have_attributes(extraction_status: "not_requested", extraction_requested_at: nil)
      expect(processing_recap.reload).to have_attributes(extraction_status: "not_requested", extraction_started_at: nil)
    end

    it "rejects a mismatched confirmation without deleting data" do
      ai_memory = create(:memory_record, relationship_profile: profile, source: "ai_inferred")

      post data_deletions_path, params: { data_deletion: { kind: "ai_generated", confirmation: "wrong@example.com" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(MemoryRecord.exists?(ai_memory.id)).to be(true)
      expect(DeletionRequest.count).to eq(0)
    end

    it "records an explicit request when an owned relationship profile is deleted" do
      delete relationship_profile_path(profile)

      expect(response).to redirect_to(relationship_profiles_path)
      expect(RelationshipProfile.exists?(profile.id)).to be(false)
      expect(user.deletion_requests.last).to have_attributes(
        request_kind: "relationship_profile",
        subject_type: "RelationshipProfile",
        subject_id: profile.id,
        status: "completed"
      )
    end

    it "permanently deletes an owned protected record only while the vault is unlocked" do
      memory = create(:memory_record, relationship_profile: profile, title: "Private plan", body: "Meet at noon")
      item = PrivacyVault::Protect.call(actor: user, protectable: memory)

      delete delete_data_relationship_profile_privacy_vault_item_path(profile, item)
      expect(response).to redirect_to(relationship_profile_privacy_vault_path(profile))
      expect(MemoryRecord.exists?(memory.id)).to be(true)

      post unlock_relationship_profile_privacy_vault_path(profile),
        params: { privacy_vault_unlock: { password: } }
      delete delete_data_relationship_profile_privacy_vault_item_path(profile, item)

      expect(response).to redirect_to(relationship_profile_privacy_vault_path(profile))
      expect(MemoryRecord.exists?(memory.id)).to be(false)
      expect(user.deletion_requests.last).to have_attributes(
        request_kind: "privacy_vault_item",
        subject_type: "PrivacyVaultItem",
        subject_id: item.id,
        status: "completed"
      )
    end

    it "deletes the account only after email and password confirmation and preserves deletion evidence" do
      profile

      recap = create(:conversation_recap, relationship_profile: profile)
      recap.audio_recording.attach(
        io: StringIO.new("delete this recording"),
        filename: "delete-me.webm",
        content_type: "audio/webm"
      )
      blob = recap.audio_recording.blob
      blob_key = blob.key

      feature_flag = create(:feature_flag)
      feature_flag_event = create(:feature_flag_audit_event, feature_flag:, actor: user)
      user_assignment = create(:feature_flag_assignment, feature_flag:, target_kind: "user", target_value: user.id)

      expect do
        post data_deletions_path, params: {
          data_deletion: { kind: "account", confirmation: user.email, current_password: password }
        }
      end.to change(User, :count).by(-1)

      expect(response).to redirect_to(root_path)
      request_record = DeletionRequest.order(:created_at).last
      expect(request_record).to have_attributes(
        user_id: nil,
        request_kind: "account",
        status: "completed",
        completed_at: be_present
      )
      expect(request_record.account_digest).to be_present
      expect(request_record.attributes.to_json).not_to include(user.email)
      expect(feature_flag_event.reload.actor).to be_nil
      expect(FeatureFlagAssignment.exists?(user_assignment.id)).to be(false)
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
      expect(ActiveStorage::Blob.service.exist?(blob_key)).to be(false)
    end

    it "permanently deletes social context screenshots with the account" do
      blob = create_social_context_image_blob(user:, filename: "delete-me.png", payload: "delete this screenshot")
      create(
        :social_context_note,
        relationship_profile: profile,
        body: "<p>Social post</p>#{ActionText::Attachment.from_attachable(blob).to_html}"
      )
      blob_key = blob.key

      post data_deletions_path, params: {
        data_deletion: { kind: "account", confirmation: user.email, current_password: password }
      }

      expect(response).to redirect_to(root_path)
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
      expect(ActiveStorage::Blob.service.exist?(blob_key)).to be(false)
    end

    it "revokes and purges an unattached direct-upload grant with the account" do
      post social_context_direct_uploads_path, params: {
        blob: {
          filename: "abandoned.png",
          byte_size: 8,
          checksum: Digest::MD5.base64digest("\x89PNG\r\n\x1A\n".b),
          content_type: "image/png"
        }
      }
      upload_url = response.parsed_body.dig("direct_upload", "url")
      blob = ActiveStorage::Blob.order(:created_at).last
      blob_key = blob.key

      post data_deletions_path, params: {
        data_deletion: { kind: "account", confirmation: user.email, current_password: password }
      }

      expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
      expect(ActiveStorage::Blob.service.exist?(blob_key)).to be(false)

      put upload_url, params: "\x89PNG\r\n\x1A\n".b, headers: { "CONTENT_TYPE" => "image/png" }

      expect(response).to redirect_to(new_user_session_path)
      expect(ActiveStorage::Blob.service.exist?(blob_key)).to be(false)
    end

    it "locks owned relationship profiles before snapshotting account screenshots" do
      blob = create_social_context_image_blob(user:, filename: "account-lock.png", payload: "account lock screenshot")
      create(
        :social_context_note,
        relationship_profile: profile,
        body: "<p>Social post</p>#{ActionText::Attachment.from_attachable(blob).to_html}"
      )
      sql = []
      subscriber = lambda do |_name, _started, _finished, _id, payload|
        sql << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:cached]
      end

      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        post data_deletions_path, params: {
          data_deletion: { kind: "account", confirmation: user.email, current_password: password }
        }
      end

      profile_lock = sql.index { |statement| statement.include?('FROM "relationship_profiles"') && statement.include?("FOR UPDATE") }
      social_snapshot = sql.index { |statement| statement.include?('FROM "social_context_notes"') }
      expect(profile_lock).to be_present
      expect(social_snapshot).to be_present
      expect(profile_lock).to be < social_snapshot
    end

    it "does not mark account deletion complete when recording purge fails" do
      recap = create(:conversation_recap, relationship_profile: profile)
      recap.audio_recording.attach(
        io: StringIO.new("purge failure"),
        filename: "failure.webm",
        content_type: "audio/webm"
      )
      blob_id = recap.audio_recording.blob.id
      allow(ActiveStorage::Blob.service).to receive(:delete).and_raise(StandardError, "storage unavailable")

      expect do
        post data_deletions_path, params: {
          data_deletion: { kind: "account", confirmation: user.email, current_password: password }
        }
      end.to raise_error(StandardError, "storage unavailable")

      expect(DeletionRequest.order(:created_at).last).to have_attributes(status: "failed", completed_at: nil)
      expect(ActiveStorage::Blob.exists?(blob_id)).to be(true)
    end

    it "completes account deletion when Active Storage already removed the blob row" do
      recap = create(:conversation_recap, relationship_profile: profile)
      recap.audio_recording.attach(
        io: StringIO.new("already purged"),
        filename: "already-purged.webm",
        content_type: "audio/webm"
      )
      blob_key = recap.audio_recording.blob.key
      allow_any_instance_of(ActiveStorage::Blob).to receive(:with_lock).and_raise(ActiveRecord::RecordNotFound)

      post data_deletions_path, params: {
        data_deletion: { kind: "account", confirmation: user.email, current_password: password }
      }

      expect(response).to redirect_to(root_path)
      expect(DeletionRequest.order(:created_at).last).to have_attributes(status: "completed", completed_at: be_present)
      expect(ActiveStorage::Blob.service.exist?(blob_key)).to be(false)
    end

    it "preserves a recording blob that remains attached to another account" do
      deleting_recap = create(:conversation_recap, relationship_profile: profile)
      other_user = create(:user)
      other_recap = create(:conversation_recap, relationship_profile: create(:relationship_profile, user: other_user))
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("shared recording"),
        filename: "shared.webm",
        content_type: "audio/webm"
      )
      deleting_recap.audio_recording.attach(blob)
      other_recap.audio_recording.attach(blob)
      blob_key = blob.key

      post data_deletions_path, params: {
        data_deletion: { kind: "account", confirmation: user.email, current_password: password }
      }

      expect(response).to redirect_to(root_path)
      expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
      expect(ActiveStorage::Blob.service.exist?(blob_key)).to be(true)
      expect(other_recap.reload.audio_recording.download).to eq("shared recording")
    end

    it "locks a recording blob while checking attachments and deleting storage" do
      recap = create(:conversation_recap, relationship_profile: profile)
      recap.audio_recording.attach(
        io: StringIO.new("serialized purge"),
        filename: "serialized.webm",
        content_type: "audio/webm"
      )

      expect_any_instance_of(ActiveStorage::Blob).to receive(:with_lock).once.and_call_original

      post data_deletions_path, params: {
        data_deletion: { kind: "account", confirmation: user.email, current_password: password }
      }

      expect(response).to redirect_to(root_path)
    end

    it "rejects account deletion when the password is invalid" do
      post data_deletions_path, params: {
        data_deletion: { kind: "account", confirmation: user.email, current_password: "wrong-password" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(User.exists?(user.id)).to be(true)
      expect(DeletionRequest.count).to eq(0)
    end

    it "filters deletion confirmation emails from parameter logs" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

      filtered = filter.filter("data_deletion" => { "confirmation" => user.email })

      expect(filtered.dig("data_deletion", "confirmation")).to eq("[FILTERED]")
    end
  end
end
