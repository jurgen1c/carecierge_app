require "rails_helper"

RSpec.describe "Conversational memory proposals", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Ana said the garden was peaceful", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }
  let(:arguments) { { title: "Quiet places", body: "Ana may enjoy peaceful outdoor places", source_excerpt: "the garden was peaceful" } }

  def propose(values = arguments)
    Concierge::Execute.call(turn:, token:, name: "memories.propose", arguments: values)
  end

  it "keeps an inferred interpretation as an exact review proposal until the owner accepts it" do
    result = propose
    expect(result).to include("status" => "awaiting_approval")
    expect(profile.memory_records).to be_empty
    action = turn.actions.find(result.fetch("action_id"))
    expect(action.result.fetch("preview")).to include(arguments[:source_excerpt], arguments[:body])
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    memory = profile.memory_records.sole
    expect(memory).to have_attributes(source: "ai_inferred", confidence: "inferred", body: arguments[:body])
    expect(memory).to be_high_impact_automation_blocked
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(profile.memory_records.count).to eq(1)
  end

  it "discards a rejected proposal without creating a canonical memory" do
    action = turn.actions.find(propose.fetch("action_id"))
    Concierge::Decide.call(user:, action:, decision: "reject", fingerprint: action.fingerprint)
    expect(profile.memory_records).to be_empty
  end

  it "refuses a fabricated supporting quote before storing a proposal" do
    expect { propose(arguments.merge(source_excerpt: "Ana wants to move abroad")) }.to raise_error(Concierge::InvalidArguments)
    expect(turn.actions.reload).to be_empty
    expect(profile.memory_records).to be_empty
  end
end
