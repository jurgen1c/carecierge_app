require "rails_helper"

RSpec.describe "Local AI feature routing" do
  let(:chat) { double("RubyLLM chat", with_instructions: nil, with_params: nil, with_schema: nil) }
  let(:context) { double("RubyLLM context", chat:) }
  let(:response) { double("RubyLLM response", content: output, raw: nil) }
  let(:output) { "A thoughtful draft" }

  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("development"))
    allow(Rails.application.credentials).to receive(:dig).and_return(nil)
    allow(RubyLLM).to receive(:context).and_return(context)
    allow(chat).to receive(:ask).and_return(response)
    expect(Net::HTTP).not_to receive(:start)
  end

  it "drafts messages locally without an OpenAI key and preserves Spanish instructions" do
    result = MessageDrafts::OpenAiGenerator.new(api_key: "").generate(
      draft_type: "check_in", tone: "warm", context: "Ana prefers quiet restaurants", locale: :es)

    expect(result).to eq(output)
    expect(context).to have_received(:chat).with(provider: :ollama, model: "carecierge-dev", assume_model_exists: true)
    expect(chat).to have_received(:with_instructions).with(a_string_including("Spanish", "untrusted", "Never send"))
    expect(chat).to have_received(:with_params).with(max_tokens: 700, reasoning_effort: "none")
    expect(chat).to have_received(:ask).with(a_string_including("Ana prefers quiet restaurants"), with: nil)
  end

  context "with structured output" do
    let(:output) { { "sections" => [], "recommendations" => [], "memories" => [] } }

    it "generates source-backed briefings locally" do
      result = RelationshipBriefings::OpenAiGenerator.new(api_key: "").generate(
        interaction_context: "Lunch", sources: [], locale: :en)

      expect(result).to eq([])
      expect(chat).to have_received(:with_schema).with(name: "relationship_briefing", schema: RelationshipBriefings::OpenAiGenerator::SCHEMA)
    end

    it "generates gift ideas locally" do
      result = GiftRecommendations::OpenAiGenerator.new(api_key: "").generate(
        sources: [], budget_cents: 2500, needed_by: nil, occasion: "birthday", allow_repeats: false, excluded_titles: [], locale: :es)

      expect(result).to eq([])
      expect(chat).to have_received(:ask).with(a_string_including('"budget_cents":2500'), with: nil)
    end

    it "extracts review-only memories locally" do
      recap = build_stubbed(:conversation_recap, title: "Lunch", body: "Ana likes quiet restaurants")

      expect(MemoryExtractions::OpenAiExtractor.new(api_key: "").extract(recap)).to eq([])
      expect(chat).to have_received(:ask).with(a_string_including("Ana likes quiet restaurants"), with: nil)
    end
  end

  context "with social context" do
    let(:output) { { "interpretation" => "May enjoy books", "suggested_uses" => [ "gift" ] } }

    it "analyzes deliberately supplied text locally" do
      input = SocialContextNotes::AnalysisInput.new(text: "A bookstore event", image_blob_ids: [])

      expect(SocialContextNotes::OpenAiAnalyzer.new(api_key: "").analyze(input:, locale: :en)).to eq(
        interpretation: "May enjoy books", suggested_uses: [ "gift" ])
    end
  end

  it "returns a recoverable domain error on local provider failure without cloud fallback" do
    allow(chat).to receive(:ask).and_raise(Faraday::TimeoutError, "private provider detail")

    expect do
      MessageDrafts::OpenAiGenerator.new(api_key: "").generate(draft_type: "check_in", tone: "warm", context: "")
    end.to raise_error(MessageDrafts::GenerationError, "Message drafting provider was unavailable")
  end
end
