require "rails_helper"

RSpec.describe "Message drafts", type: :request do
  it "renders the profile-first drafting workspace without a sending capability" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    sign_in user

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Write with context", "Draft only — nothing will be sent")
    expect(response.body).not_to match(/>\s*Send\s*</)
  end

  it "generates an owner-scoped draft using safe relationship context" do
    user = create(:user)
    profile = create(:relationship_profile, user:, preferred_name: "Maya")
    create(:relationship_preference, relationship_profile: profile, key: "Message style", value: "Short and sincere")
    generator = instance_double(MessageDrafts::OpenAiGenerator)
    allow(MessageDrafts::OpenAiGenerator).to receive(:new).and_return(generator)
    expect(generator).to receive(:generate).with(
      draft_type: "birthday",
      tone: "warm",
      context: a_string_including("Maya", "Short and sincere"),
      locale: :en
    ).and_return("Happy birthday, Maya!")
    sign_in user

    post generate_relationship_profile_message_draft_path(profile), params: {
      message_draft: { draft_type: "birthday", tone: "warm" }
    }

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "message-drafting"))
    expect(profile.reload.message_draft.current_revision.content).to eq("Happy birthday, Maya!")
  end

  it "includes private notes only after explicit permission" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:relationship_note, relationship_profile: profile, private: true, body: "Use a gentle opening.")
    generator = instance_double(MessageDrafts::OpenAiGenerator)
    allow(MessageDrafts::OpenAiGenerator).to receive(:new).and_return(generator)
    expect(generator).to receive(:generate).with(
      draft_type: "check_in",
      tone: "warm",
      context: a_string_including("Use a gentle opening"),
      locale: :en
    ).and_return("Just checking in gently.")
    sign_in user

    post generate_relationship_profile_message_draft_path(profile), params: {
      message_draft: {
        draft_type: "check_in",
        tone: "warm",
        use_private_notes: "1"
      }
    }

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "message-drafting"))
    expect(profile.reload.message_draft.current_revision.context_categories).to include("private_notes")
  end

  it "requires an active vault lease before vault context can be granted" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    generator = instance_double(MessageDrafts::OpenAiGenerator)
    allow(MessageDrafts::OpenAiGenerator).to receive(:new).and_return(generator)
    expect(generator).not_to receive(:generate)
    sign_in user

    post generate_relationship_profile_message_draft_path(profile), params: {
      message_draft: {
        draft_type: "boundary_setting",
        tone: "concise",
        use_vault_context: "1"
      }
    }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(profile))
    expect(profile.reload.message_draft).to be_nil
  end

  it "requires vault unlock again when the lease is revoked before context is read" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    revoked_lease = PrivacyVault::Lease.issue_for(user)
    user.increment!(:privacy_vault_lease_version)
    generator = instance_double(MessageDrafts::OpenAiGenerator)
    allow(MessageDrafts::OpenAiGenerator).to receive(:new).and_return(generator)
    allow_any_instance_of(MessageDraftsController).to receive(:touch_privacy_vault_lease!).and_return(true)
    allow_any_instance_of(MessageDraftsController).to receive(:privacy_vault_lease).and_return(revoked_lease)
    expect(generator).not_to receive(:generate)
    sign_in user

    post generate_relationship_profile_message_draft_path(profile), params: {
      message_draft: {
        draft_type: "boundary_setting",
        tone: "concise",
        use_vault_context: "1"
      }
    }

    expect(response).to redirect_to(relationship_profile_privacy_vault_path(profile))
    expect(profile.reload.message_draft).to be_nil
  end

  it "uses vault context after password-backed unlock and explicit permission" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    create(:privacy_vault_item, relationship_profile: profile, payload: { "title" => "Protected boundary", "body" => "Avoid discussing work." })
    generator = instance_double(MessageDrafts::OpenAiGenerator)
    allow(MessageDrafts::OpenAiGenerator).to receive(:new).and_return(generator)
    expect(generator).to receive(:generate).with(
      draft_type: "boundary_setting",
      tone: "concise",
      context: a_string_including("Protected boundary", "Avoid discussing work"),
      locale: :en
    ).and_return("I need us to leave work out of this conversation.")
    sign_in user
    post unlock_relationship_profile_privacy_vault_path(profile), params: {
      privacy_vault_unlock: { password: "password123" }
    }

    post generate_relationship_profile_message_draft_path(profile), params: {
      message_draft: {
        draft_type: "boundary_setting",
        tone: "concise",
        use_vault_context: "1"
      }
    }

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "message-drafting"))
    expect(profile.reload.message_draft.current_revision.context_categories).to include("vault")
  end

  it "saves edits and restores history by appending revisions" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    draft = create(:message_draft, user:, relationship_profile: profile)
    original = create(:draft_revision, message_draft: draft, position: 1, content: "Original")
    sign_in user

    patch relationship_profile_message_draft_path(profile), params: {
      message_draft: { draft_type: "birthday", tone: "warm", content: "Edited" }
    }
    post restore_revision_relationship_profile_message_draft_path(profile, revision_id: original.id)

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "message-drafting"))
    expect(draft.reload.draft_revisions.pluck(:position, :origin, :content)).to include(
      [ 2, "edited", "Edited" ],
      [ 3, "restored", "Original" ]
    )
  end

  it "paginates immutable history while keeping the editor on the current revision" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    draft = create(:message_draft, user:, relationship_profile: profile)
    12.times do |index|
      create(:draft_revision, message_draft: draft, position: index + 1, content: format("Revision content %02d", index + 1))
    end
    sign_in user

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Revision content 12", "Revision content 03", "Page 1 of 2")
    expect(response.body).not_to include("Revision content 02", "Revision content 01")
    expect(response.body.scan("Restore").size).to eq(10)

    get relationship_profile_path(profile), params: { draft_page: 2 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Revision content 12", "Revision content 02", "Revision content 01", "Page 2 of 2")
    expect(response.body).not_to include("Revision content 03")
    expect(response.body.scan("Restore").size).to eq(2)
    expect(response.body).not_to include(">Current<")
  end

  it "deletes the retained draft and all of its revisions" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    draft = create(:message_draft, user:, relationship_profile: profile)
    create(:draft_revision, message_draft: draft)
    sign_in user

    expect do
      delete relationship_profile_message_draft_path(profile)
    end.to change(MessageDraft, :count).by(-1).and change(DraftRevision, :count).by(-1)

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "message-drafting"))
  end

  it "returns not found across account boundaries" do
    profile = create(:relationship_profile)
    sign_in create(:user)

    post generate_relationship_profile_message_draft_path(profile), params: {
      message_draft: { draft_type: "birthday", tone: "warm" }
    }

    expect(response).to have_http_status(:not_found)
    expect(profile.reload.message_draft).to be_nil
  end

  it "returns not found when generating for an archived profile" do
    user = create(:user)
    profile = create(:relationship_profile, user:, discarded_at: Time.current)
    sign_in user

    post generate_relationship_profile_message_draft_path(profile), params: {
      message_draft: { draft_type: "check_in", tone: "warm" }
    }

    expect(response).to have_http_status(:not_found)
    expect(profile.reload.message_draft).to be_nil
  end

  it "does not render message-draft mutation controls for archived profiles" do
    user = create(:user)
    profile = create(:relationship_profile, user:, discarded_at: Time.current)
    draft = create(:message_draft, user:, relationship_profile: profile)
    create(:draft_revision, message_draft: draft)
    sign_in user

    get relationship_profile_path(profile)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('id="message-drafting"')
  end
end
