require "rails_helper"

RSpec.describe MemoryExtractionJob, type: :job do
  it "hands an enabled extraction request to the extraction service" do
    recap = create(:conversation_recap, extraction_status: "requested", extraction_requested_at: Time.current)
    flag = create(:feature_flag, key: "ai_memory_extraction")
    create(:feature_flag_assignment, feature_flag: flag, target_kind: "user", target_value: recap.relationship_profile.user_id)
    allow(MemoryExtractions::Extract).to receive(:call)

    described_class.perform_now(recap)

    expect(MemoryExtractions::Extract).to have_received(:call).with(conversation_recap: recap)
  end

  it "does not process requests while the rollout flag is disabled" do
    recap = create(:conversation_recap, extraction_status: "requested", extraction_requested_at: Time.current)
    create(:feature_flag, key: "ai_memory_extraction", enabled: false)
    allow(MemoryExtractions::Extract).to receive(:call)

    described_class.perform_now(recap)

    expect(MemoryExtractions::Extract).not_to have_received(:call)
    expect(recap.reload).to have_attributes(
      extraction_status: "failed",
      extraction_error_code: "feature_disabled"
    )
  end
end
