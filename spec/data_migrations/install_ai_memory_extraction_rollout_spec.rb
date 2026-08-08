require "rails_helper"
require Rails.root.join("db/data/20260808060000_install_ai_memory_extraction_rollout")

RSpec.describe InstallAiMemoryExtractionRollout do
  it "installs the disabled flag and makes legacy requests retryable" do
    requested_recap = create(:conversation_recap, extraction_status: "requested", extraction_requested_at: 1.day.ago)
    processing_recap = create(
      :conversation_recap,
      extraction_status: "processing",
      extraction_requested_at: 1.day.ago,
      extraction_started_at: 1.hour.ago
    )

    described_class.new.up

    expect(FeatureFlag.find_by!(key: "ai_memory_extraction")).to have_attributes(
      name: "AI memory extraction",
      enabled: false
    )
    expect(requested_recap.reload).to have_attributes(
      extraction_status: "failed",
      extraction_error_code: "extraction_interrupted"
    )
    expect(processing_recap.reload).to have_attributes(
      extraction_status: "failed",
      extraction_error_code: "extraction_interrupted"
    )
  end

  it "is idempotent and does not overwrite an existing rollout configuration" do
    flag = create(:feature_flag, key: "ai_memory_extraction", name: "Custom rollout", enabled: true)

    2.times { described_class.new.up }

    expect(flag.reload).to have_attributes(name: "Custom rollout", enabled: true)
    expect(FeatureFlag.where(key: "ai_memory_extraction").count).to eq(1)
  end
end
