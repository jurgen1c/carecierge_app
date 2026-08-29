require "rails_helper"

RSpec.describe "Extracted memory reviews", type: :request do
  it "renders a responsive source-backed review queue on the profile" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    recap = create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review", title: "Dinner recap")
    selected = create(:extracted_memory, relationship_profile: profile, conversation_recap: recap, title: "Likes jazz")
    create(:extracted_memory, relationship_profile: profile, conversation_recap: recap, category: "gift_idea", title: "Vinyl record")
    sign_in user

    get relationship_profile_path(profile, memory_proposal: selected.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Suggestions awaiting your judgment")
    expect(response.body).to include("Likes jazz")
    expect(response.body).to include("Vinyl record")
    expect(response.body).to include("Why this was suggested")
    expect(response.body).to include("Approve memory")
    expect(response.body).not_to include("Translation missing")
  end

  it "approves an owner-scoped proposal" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review"))
    sign_in user

    expect do
      patch review_relationship_profile_extracted_memory_path(profile, proposal),
        params: { extracted_memory: { decision: "approve" } }
    end.to change(MemoryRecord, :count).by(1)

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "memory-review"))
    expect(proposal.reload.status).to eq("approved")
  end

  it "rejects a mismatched retry after the proposal was already reviewed" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review")
    )
    sign_in user

    patch review_relationship_profile_extracted_memory_path(profile, proposal),
      params: { extracted_memory: { decision: "reject" } }

    expect do
      patch review_relationship_profile_extracted_memory_path(profile, proposal),
        params: { extracted_memory: { decision: "approve" } }
    end.not_to change { [ ApprovalRequest.count, ApprovalDecision.count, MemoryRecord.count ] }

    expect(response).to redirect_to(
      relationship_profile_path(profile, memory_proposal: proposal.id, anchor: "memory-review")
    )
    expect(flash[:alert]).to eq(I18n.t("extracted_memories.review.already_reviewed"))
    expect(proposal.reload.status).to eq("rejected")
  end

  it "records an explicit source reversal after a dismissed queue item" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(
      :extracted_memory,
      relationship_profile: profile,
      conversation_recap: create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review")
    )
    dismissed_request = create(
      :approval_request,
      user:,
      subject: proposal,
      status: "dismissed",
      decided_at: Time.current
    )
    ApprovalDecision.create!(approval_request: dismissed_request, user:, decision: "dismiss", occurred_at: Time.current)
    sign_in user

    expect do
      patch review_relationship_profile_extracted_memory_path(profile, proposal),
        params: { extracted_memory: { decision: "approve" } }
    end.to change(ApprovalRequest, :count).by(1)
      .and change(ApprovalDecision, :count).by(1)

    reversal = user.approval_requests.where(subject: proposal).order(:created_at).last
    expect(proposal.reload.status).to eq("approved")
    expect(reversal).to have_attributes(status: "approved", action_key: "review_extracted_memory")
    expect(reversal.approval_decisions.sole).to have_attributes(decision: "approve", user:)
  end

  it "corrects an owner-scoped proposal" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review"))
    sign_in user

    patch review_relationship_profile_extracted_memory_path(profile, proposal),
      params: {
        extracted_memory: {
          decision: "correct",
          corrected_title: "Enjoys jasmine tea",
          corrected_body: "Enjoys jasmine tea on quiet evenings."
        }
      }

    expect(response).to redirect_to(relationship_profile_path(profile, anchor: "memory-review"))
    expect(proposal.reload.canonical_memory_record).to have_attributes(source: "user_corrected", confidence: "confirmed")
  end

  it "reports an unsupported review decision separately from an invalid correction" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review"))
    sign_in user

    patch review_relationship_profile_extracted_memory_path(profile, proposal),
      params: { extracted_memory: { decision: "publish" } }

    expect(response).to redirect_to(relationship_profile_path(profile, memory_proposal: proposal.id, anchor: "memory-review"))
    expect(flash[:alert]).to eq(I18n.t("extracted_memories.review.invalid_decision"))
    expect(proposal.reload.status).to eq("pending")
  end

  it "rejects queue-only decisions on the source review endpoint" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review"))
    sign_in user

    %w[dismiss edit defer].each do |decision|
      patch review_relationship_profile_extracted_memory_path(profile, proposal),
        params: { extracted_memory: { decision: } }

      expect(response).to redirect_to(relationship_profile_path(profile, memory_proposal: proposal.id, anchor: "memory-review"))
      expect(flash[:alert]).to eq(I18n.t("extracted_memories.review.invalid_decision"))
      expect(proposal.reload.status).to eq("pending")
      expect(user.approval_requests.where(subject: proposal)).to be_empty
    end
  end

  it "returns not found across tenant boundaries" do
    profile = create(:relationship_profile)
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: create(:conversation_recap, relationship_profile: profile))
    sign_in create(:user)

    patch review_relationship_profile_extracted_memory_path(profile, proposal),
      params: { extracted_memory: { decision: "approve" } }

    expect(response).to have_http_status(:not_found)
    expect(proposal.reload.status).to eq("pending")
  end
end
