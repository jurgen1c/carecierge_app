require "rails_helper"

RSpec.describe "Social context notes", type: :request do
  it "renders the relationship-scoped manual context ledger in English and Spanish" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:social_context_note, relationship_profile: profile, body: "Maya posted about a bookstore event.")
    sign_in user

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Social context", "Only context you add appears here", "Maya posted about a bookstore event")
    expect(response.body).not_to include("Translation missing")

    I18n.with_locale(:es) { get relationship_profile_path(profile) }

    expect(response.body).to include("Contexto social", "Solo aparece el contexto que agregas")
    expect(response.body).not_to include("Translation missing")
  end

  it "creates notes with downstream use off by default and can explicitly enable it" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    sign_in user

    expect do
      post relationship_profile_social_context_notes_path(profile), params: {
        social_context_note: { body: "Maya posted about a bookstore event." }
      }
    end.to change(SocialContextNote, :count).by(1)

    expect(SocialContextNote.last.allow_suggestions).to be(false)
    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "social-context"))

    post relationship_profile_social_context_notes_path(profile, social_context_page: 2), params: {
      social_context_note: {
        body: "Maya shared an upcoming neighborhood event.",
        allow_suggestions: "1"
      }
    }

    expect(profile.social_context_notes.where(allow_suggestions: true)).to exist
    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "social-context"))
  end

  it "approves a reviewed interpretation and invalidates stale analysis after an unreviewed source edit" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(
      :social_context_note,
      relationship_profile: profile,
      interpretation: "This may be a conversation topic.",
      interpretation_status: "draft",
      suggested_uses: %w[conversation_topic]
    )
    sign_in user

    patch relationship_profile_social_context_note_path(profile, note), params: {
      social_context_note: {
        body: note.body.to_s,
        interpretation: "This may be a gentle conversation topic.",
        suggested_uses: %w[message],
        allow_suggestions: "1",
        approve_interpretation: "1",
        lock_version: note.lock_version
      }
    }

    expect(note.reload).to have_attributes(
      interpretation: "This may be a gentle conversation topic.",
      interpretation_status: "approved",
      suggested_uses: %w[message],
      allow_suggestions: true
    )

    patch relationship_profile_social_context_note_path(profile, note), params: {
      social_context_note: {
        body: "A materially different source note.",
        allow_suggestions: "1",
        lock_version: note.lock_version
      }
    }

    expect(note.reload).to have_attributes(
      interpretation: nil,
      interpretation_status: "not_requested",
      suggested_uses: []
    )
  end

  it "re-renders invalid submissions with the entered content and accessible errors" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:social_context_note, relationship_profile: profile, body: "Original context")
    sign_in user

    post relationship_profile_social_context_notes_path(profile), params: {
      social_context_note: { body: "A" * (SocialContextNote::MAX_BODY_CHARACTERS + 1) }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("A" * 100)
    expect(response.body).to include("role=\"alert\"")

    patch relationship_profile_social_context_note_path(profile, note), params: {
      social_context_note: {
        body: "B" * (SocialContextNote::MAX_BODY_CHARACTERS + 1),
        lock_version: note.lock_version
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("B" * 100)
    expect(response.body).to include("role=\"alert\"")
  end

  it "paginates the editor-heavy ledger while reusing a bounded downstream collection" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    notes = create_list(
      :social_context_note,
      RelationshipProfileShowWorkspace::SOCIAL_CONTEXT_PAGE_SIZE + 1,
      relationship_profile: profile,
      allow_suggestions: true
    )
    sign_in user

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body.scan("lexxy-editor").size).to eq((RelationshipProfileShowWorkspace::SOCIAL_CONTEXT_PAGE_SIZE + 1) * 2)
    expect(response.body).to include("Showing 1–#{RelationshipProfileShowWorkspace::SOCIAL_CONTEXT_PAGE_SIZE}")

    get relationship_profile_path(profile, social_context_page: 2)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(notes.first.body.to_plain_text.squish)
    expect(response.body).to include("Page 2 of 2")
  end


  it "normalizes repeated submitted suggested uses before persistence" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(
      :social_context_note,
      relationship_profile: profile,
      interpretation: "A conversation may be timely.",
      interpretation_status: "draft"
    )
    sign_in user

    patch relationship_profile_social_context_note_path(profile, note), params: {
      social_context_note: {
        interpretation: note.interpretation,
        suggested_uses: %w[message message conversation_topic],
        approve_interpretation: "1",
        lock_version: note.lock_version
      }
    }

    expect(note.reload.suggested_uses).to eq(%w[message conversation_topic])
  end

  it "rejects an edit submitted from a stale rendered revision" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:social_context_note, relationship_profile: profile)
    rendered_lock_version = note.lock_version
    note.update!(body: "A newer saved revision")
    sign_in user

    patch relationship_profile_social_context_note_path(profile, note), params: {
      social_context_note: { body: "Stale overwrite", lock_version: rendered_lock_version }
    }

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "row_social_context_note_#{note.id}"))
    expect(flash[:alert]).to eq("The note changed before your update was saved. Review it and try again.")
    expect(note.reload.body.to_plain_text).to include("A newer saved revision")
    expect(note.body.to_plain_text).not_to include("Stale overwrite")
  end

  it "rejects an update without optimistic-lock evidence" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:social_context_note, relationship_profile: profile, body: "Original context")
    sign_in user

    patch relationship_profile_social_context_note_path(profile, note), params: {
      social_context_note: { body: "Unversioned overwrite" }
    }

    expect(response).to have_http_status(:bad_request)
    expect(note.reload.body.to_plain_text).to include("Original context")
    expect(note.body.to_plain_text).not_to include("Unversioned overwrite")
  end

  it "requires the configured automation permission before explicit analysis" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:social_context_note, relationship_profile: profile)
    analyzer = instance_double(SocialContextNotes::OpenAiAnalyzer)
    allow(SocialContextNotes::OpenAiAnalyzer).to receive(:new).and_return(analyzer)
    expect(analyzer).not_to receive(:analyze)
    sign_in user

    post analyze_relationship_profile_social_context_note_path(profile, note), params: {
      explicit_approval: "1",
      lock_version: note.lock_version
    }

    expect(response).to redirect_to(
      edit_automation_permissions_path(
        capability: "analyze_uploaded_social_content",
        anchor: "capability-panel-analyze_uploaded_social_content"
      )
    )
    expect(note.reload.interpretation).to be_nil
  end

  it "analyzes only after an explicit user action under an enabled permission" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:social_context_note, relationship_profile: profile)
    create(
      :automation_permission,
      user:,
      capability: "analyze_uploaded_social_content",
      mode: "ask_every_time"
    )
    analyzer = instance_double(SocialContextNotes::OpenAiAnalyzer)
    allow(SocialContextNotes::OpenAiAnalyzer).to receive(:new).and_return(analyzer)
    expect(analyzer).to receive(:analyze).with(
      input: have_attributes(text: a_string_including("neighborhood bookshop"), image_blob_ids: []),
      locale: :en
    ).and_return(
      interpretation: "This may be a useful message topic.",
      suggested_uses: %w[message]
    )
    sign_in user

    post analyze_relationship_profile_social_context_note_path(profile, note), params: {
      explicit_approval: "1",
      lock_version: note.lock_version
    }

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "row_social_context_note_#{note.id}"))
    expect(note.reload).to have_attributes(interpretation_status: "draft")
  end

  it "saves the edited source before analyzing the submitted revision" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:social_context_note, relationship_profile: profile, body: "Old private context")
    create(
      :automation_permission,
      user:,
      capability: "analyze_uploaded_social_content",
      mode: "ask_every_time"
    )
    analyzer = instance_double(SocialContextNotes::OpenAiAnalyzer)
    allow(SocialContextNotes::OpenAiAnalyzer).to receive(:new).and_return(analyzer)
    expect(analyzer).to receive(:analyze).with(
      input: have_attributes(text: a_string_including("Fresh user-edited context"), image_blob_ids: []),
      locale: :en
    ).and_return(
      interpretation: "This may be useful context.",
      suggested_uses: %w[message]
    )
    sign_in user

    patch relationship_profile_social_context_note_path(profile, note), params: {
      intent: "analyze",
      social_context_note: {
        body: "Fresh user-edited context",
        lock_version: note.lock_version
      }
    }

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "row_social_context_note_#{note.id}"))
    expect(note.reload.body.to_plain_text).to include("Fresh user-edited context")
    expect(note).to have_attributes(interpretation_status: "draft")
  end

  it "does not send a newer revision when analysis was requested from a stale page" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    note = create(:social_context_note, relationship_profile: profile)
    rendered_lock_version = note.lock_version
    note.update!(body: "Newer private context")
    create(
      :automation_permission,
      user:,
      capability: "analyze_uploaded_social_content",
      mode: "ask_every_time"
    )
    analyzer = instance_double(SocialContextNotes::OpenAiAnalyzer)
    allow(SocialContextNotes::OpenAiAnalyzer).to receive(:new).and_return(analyzer)
    expect(analyzer).not_to receive(:analyze)
    sign_in user

    post analyze_relationship_profile_social_context_note_path(profile, note), params: {
      explicit_approval: "1",
      lock_version: rendered_lock_version
    }

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "row_social_context_note_#{note.id}"))
    expect(flash[:alert]).to eq("The note changed during analysis. Review it and try again.")
    expect(note.reload.interpretation).to be_nil
  end

  it "links suggestion evidence to the ledger page containing its source" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    source = create(
      :social_context_note,
      relationship_profile: profile,
      allow_suggestions: true,
      interpretation: "A reviewed conversation topic.",
      interpretation_status: "approved",
      suggested_uses: %w[conversation_topic],
      created_at: 1.day.ago
    )
    5.times do |index|
      create(
        :social_context_note,
        relationship_profile: profile,
        allow_suggestions: true,
        created_at: index.minutes.ago
      )
    end
    sign_in user

    get relationship_profile_path(profile)

    expect(response.body).to include(
      relationship_profile_path(
        profile,
        social_context_page: 2,
        anchor: "row_social_context_note_#{source.id}"
      )
    )
  end

  it "permanently deletes the note and its unshared uploaded screenshots" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    blob = create_social_context_image_blob(user:, filename: "social-context.png", payload: "screenshot bytes")
    note = create(
      :social_context_note,
      relationship_profile: profile,
      body: "<p>Bookshop post</p>#{ActionText::Attachment.from_attachable(blob).to_html}"
    )
    sign_in user

    expect do
      delete relationship_profile_social_context_note_path(profile, note)
    end.to change(SocialContextNote, :count).by(-1)

    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "social-context"))
  end

  it "captures a replacement screenshot inside the same lock as note deletion" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    original_blob = create_social_context_image_blob(user:, filename: "original.png", payload: "original screenshot")
    replacement_blob = create_social_context_image_blob(user:, filename: "replacement.png", payload: "replacement screenshot")
    note = create(
      :social_context_note,
      relationship_profile: profile,
      body: "<p>Original</p>#{ActionText::Attachment.from_attachable(original_blob).to_html}"
    )
    allow_any_instance_of(SocialContextNote).to receive(:destroy_from_user!).and_wrap_original do |method|
      record = method.receiver
      record.update!(body: "<p>Replacement</p>#{ActionText::Attachment.from_attachable(replacement_blob).to_html}")
      method.call
    end
    sign_in user

    delete relationship_profile_social_context_note_path(profile, note)

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "social-context"))
    expect(ActiveStorage::Blob.exists?(replacement_blob.id)).to be(false)
  end

  it "redirects to an in-range ledger page after deleting the final note on the last page" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    base_time = Time.zone.local(2026, 8, 13, 9)
    6.times do |index|
      create(
        :social_context_note,
        relationship_profile: profile,
        body: "Social context #{index}",
        created_at: base_time + index.minutes
      )
    end
    last_page_note = profile.social_context_notes.recent_first.offset(5).sole
    sign_in user

    delete relationship_profile_social_context_note_path(profile, last_page_note), params: { social_context_page: 2 }

    expect(response).to redirect_to(relationship_profile_path(profile, social_context_page: 1, anchor: "social-context"))
  end

  it "returns not found across account boundaries and for archived profiles" do
    owner = create(:user)
    profile = create(:relationship_profile, user: owner)
    note = create(:social_context_note, relationship_profile: profile)
    sign_in create(:user)

    patch relationship_profile_social_context_note_path(profile, note), params: {
      social_context_note: { body: "Cross-account edit" }
    }

    expect(response).to have_http_status(:not_found)
    expect(note.reload.body.to_plain_text).not_to include("Cross-account edit")

    sign_out :user
    sign_in owner
    profile.update!(discarded_at: Time.current)
    post analyze_relationship_profile_social_context_note_path(profile, note), params: { explicit_approval: "1" }

    expect(response).to have_http_status(:not_found)
  end

  it "uses localized Spanish attribute names in validation errors" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    sign_in user

    I18n.with_locale(:es) do
      post relationship_profile_social_context_notes_path(profile), params: {
        social_context_note: { body: "" }
      }
    end

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Nota o capturas no puede estar en blanco")
    expect(response.body).not_to include("Body no puede estar en blanco")
  end

  it "purges unshared screenshots when the relationship profile is permanently deleted" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    blob = create_social_context_image_blob(user:, filename: "profile-context.png", payload: "profile screenshot")
    create(
      :social_context_note,
      relationship_profile: profile,
      body: "<p>Social post</p>#{ActionText::Attachment.from_attachable(blob).to_html}"
    )
    sign_in user

    delete relationship_profile_path(profile)

    expect(response).to redirect_to(relationship_profiles_path)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
  end


  it "captures profile screenshots while the relationship lock is held" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    blob = create_social_context_image_blob(user:, filename: "locked-profile.png", payload: "locked profile screenshot")
    create(
      :social_context_note,
      relationship_profile: profile,
      body: "<p>Social post</p>#{ActionText::Attachment.from_attachable(blob).to_html}"
    )
    inside_profile_lock = false
    allow_any_instance_of(RelationshipProfile).to receive(:with_lock).and_wrap_original do |method, *args, &block|
      method.call(*args) do
        inside_profile_lock = true
        block.call
      ensure
        inside_profile_lock = false
      end
    end
    allow_any_instance_of(SocialContextNote).to receive(:image_blobs).and_wrap_original do |method|
      expect(inside_profile_lock).to be(true)
      method.call
    end
    sign_in user

    delete relationship_profile_path(profile)

    expect(response).to redirect_to(relationship_profiles_path)
  end
end
