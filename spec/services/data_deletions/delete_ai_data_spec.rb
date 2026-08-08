require "rails_helper"

RSpec.describe DataDeletions::DeleteAiData do
  it "locks and resets extraction state before deleting proposals" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    recap = create(
      :conversation_recap,
      relationship_profile: profile,
      extraction_status: "processing",
      extraction_started_at: 1.minute.ago
    )
    create(:extracted_memory, relationship_profile: profile, conversation_recap: recap)
    operation_order = []

    allow_any_instance_of(ConversationRecap).to receive(:update!).and_wrap_original do |method, *args|
      operation_order << :recap_reset
      method.call(*args)
    end
    allow_any_instance_of(ExtractedMemory).to receive(:destroy!).and_wrap_original do |method, *args|
      operation_order << :proposal_delete
      method.call(*args)
    end

    described_class.call(user:)

    expect(operation_order).to eq(%i[recap_reset proposal_delete])
    expect(recap.reload.extraction_status).to eq("not_requested")
  end
end
