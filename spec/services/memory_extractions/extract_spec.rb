require "rails_helper"

RSpec.describe MemoryExtractions::Extract do
  it "stores source-backed proposals without creating canonical memories" do
    recap = create(
      :conversation_recap,
      body: "We listened to jazz over dinner. Surprise visits make me uncomfortable.",
      extraction_status: "requested",
      extraction_requested_at: Time.current
    )
    extractor = instance_double(MemoryExtractions::OpenAiExtractor)
    allow(extractor).to receive(:extract).with(recap).and_return(
      [
        {
          category: "preference",
          title: "Likes jazz",
          body: "Jazz is a favorite dinner soundtrack.",
          confidence: "high",
          source_excerpt: "We listened to jazz over dinner."
        },
        {
          category: "boundary",
          title: "Avoid surprise visits",
          body: "Prefers plans to be agreed in advance.",
          confidence: "medium",
          source_excerpt: "Surprise visits make me uncomfortable."
        }
      ]
    )

    expect { described_class.call(conversation_recap: recap, extractor:) }
      .to change(ExtractedMemory, :count).by(2)
      .and change(MemoryRecord, :count).by(0)

    expect(recap.reload.extraction_status).to eq("ready_for_review")
    expect(recap.extracted_memories.pluck(:category, :confidence)).to contain_exactly(
      [ "preference", "high" ],
      [ "boundary", "medium" ]
    )
    expect(AuditEvent.where(action: "ai.memory_extracted", target: recap.relationship_profile)).to exist
  end

  it "fails closed with a privacy-safe error code" do
    recap = create(:conversation_recap, extraction_status: "requested", extraction_requested_at: Time.current)
    extractor = instance_double(MemoryExtractions::OpenAiExtractor)
    allow(extractor).to receive(:extract).and_raise(MemoryExtractions::ExtractionError, "sensitive provider response")

    expect { described_class.call(conversation_recap: recap, extractor:) }.not_to raise_error

    expect(recap.reload).to have_attributes(extraction_status: "failed", extraction_error_code: "extraction_failed")
    expect(recap.extracted_memories).to be_empty
  end

  it "rejects the complete response when a source excerpt is not present in the recap" do
    recap = create(:conversation_recap, body: "We listened to jazz over dinner.", extraction_status: "requested")
    extractor = instance_double(MemoryExtractions::OpenAiExtractor)
    allow(extractor).to receive(:extract).and_return(
      [
        {
          category: "preference",
          title: "Likes jazz",
          body: "Jazz is a favorite dinner soundtrack.",
          confidence: "high",
          source_excerpt: "She always asks for opera."
        }
      ]
    )

    expect { described_class.call(conversation_recap: recap, extractor:) }
      .not_to change(ExtractedMemory, :count)

    expect(recap.reload).to have_attributes(extraction_status: "failed", extraction_error_code: "extraction_failed")
  end

  it "does not recreate proposals after AI-data deletion cancels an in-flight extraction" do
    recap = create(:conversation_recap, body: "We listened to jazz over dinner.", extraction_status: "requested")
    extractor = instance_double(MemoryExtractions::OpenAiExtractor)
    allow(extractor).to receive(:extract) do
      DataDeletions::DeleteAiData.call(user: recap.relationship_profile.user)
      [
        {
          category: "preference",
          title: "Likes jazz",
          body: "Jazz is a favorite dinner soundtrack.",
          confidence: "high",
          source_excerpt: "We listened to jazz over dinner."
        }
      ]
    end

    expect { described_class.call(conversation_recap: recap, extractor:) }
      .not_to change(ExtractedMemory, :count)

    expect(recap.reload).to have_attributes(
      extraction_status: "not_requested",
      extraction_requested_at: nil,
      extraction_started_at: nil,
      extraction_completed_at: nil,
      extraction_error_code: nil
    )
  end

  it "reclaims processing state when a previously interrupted job is retried" do
    recap = create(
      :conversation_recap,
      body: "We listened to jazz over dinner.",
      extraction_status: "processing",
      extraction_started_at: 10.minutes.ago
    )
    extractor = instance_double(MemoryExtractions::OpenAiExtractor)
    allow(extractor).to receive(:extract).and_return(
      [
        {
          category: "preference",
          title: "Likes jazz",
          body: "Jazz is a favorite dinner soundtrack.",
          confidence: "high",
          source_excerpt: "We listened to jazz over dinner."
        }
      ]
    )

    expect { described_class.call(conversation_recap: recap, extractor:) }
      .to change(ExtractedMemory, :count).by(1)

    expect(recap.reload.extraction_status).to eq("ready_for_review")
  end
end
