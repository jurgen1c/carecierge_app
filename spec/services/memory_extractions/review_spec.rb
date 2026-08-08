require "rails_helper"

RSpec.describe MemoryExtractions::Review do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:recap) { create(:conversation_recap, relationship_profile: profile, extraction_status: "ready_for_review") }

  it "approves a proposal once while preserving AI source and uncertainty" do
    proposal = create(:extracted_memory, conversation_recap: recap, relationship_profile: profile, confidence: "medium")

    expect { described_class.call(extracted_memory: proposal, reviewer: user, decision: "approve") }
      .to change(MemoryRecord, :count).by(1)

    proposal.reload
    expect(proposal).to have_attributes(status: "approved", reviewed_by: user)
    expect(proposal.canonical_memory_record).to have_attributes(
      title: proposal.title,
      body: proposal.body,
      source: "ai_inferred",
      confidence: "medium"
    )

    expect { described_class.call(extracted_memory: proposal, reviewer: user, decision: "approve") }
      .not_to change(MemoryRecord, :count)
  end

  it "rejects a proposal without canonical mutation" do
    proposal = create(:extracted_memory, conversation_recap: recap, relationship_profile: profile)

    expect { described_class.call(extracted_memory: proposal, reviewer: user, decision: "reject") }
      .not_to change(MemoryRecord, :count)

    expect(proposal.reload).to have_attributes(status: "rejected", reviewed_by: user)
  end

  it "corrects a proposal while retaining the original and recording user-confirmed content" do
    proposal = create(
      :extracted_memory,
      conversation_recap: recap,
      relationship_profile: profile,
      title: "Likes jazz",
      body: "Jazz is always preferred."
    )

    described_class.call(
      extracted_memory: proposal,
      reviewer: user,
      decision: "correct",
      corrected_title: "Enjoys live jazz",
      corrected_body: "Enjoys live jazz for special evenings, but not every dinner."
    )

    proposal.reload
    expect(proposal).to have_attributes(
      status: "corrected",
      title: "Likes jazz",
      body: "Jazz is always preferred.",
      corrected_title: "Enjoys live jazz",
      corrected_body: "Enjoys live jazz for special evenings, but not every dinner."
    )
    expect(proposal.canonical_memory_record).to have_attributes(
      title: "Enjoys live jazz",
      source: "user_corrected",
      confidence: "confirmed"
    )
  end

  it "rejects a reviewer outside the profile ownership boundary" do
    proposal = create(:extracted_memory, conversation_recap: recap, relationship_profile: profile)

    expect {
      described_class.call(extracted_memory: proposal, reviewer: create(:user), decision: "approve")
    }.to raise_error(Pundit::NotAuthorizedError)

    expect(proposal.reload.status).to eq("pending")
    expect(proposal.canonical_memory_record).to be_nil
  end
end
