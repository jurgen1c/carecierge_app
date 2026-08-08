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
