require "rails_helper"

RSpec.describe "Executing concierge turns", type: :service do
  let(:user) { create(:user) }
  let(:conversation) { ConciergeConversation.create!(user:) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Hola", locale: "es") }
  let(:agent) { double("concierge agent") }
  let(:answer) { { content: "Hola. ¿A quién tienes en mente?", input_tokens: 12, output_tokens: 9 } }

  it "streams into encrypted persistence, finishes with usage, and does not execute a delivered job twice" do
    expect(agent).to receive(:call).once do |turn:, token:, &stream|
      expect(I18n.locale).to eq(:es)
      expect(turn.running_for?(token)).to be(true)
      stream.call("Hola.")
      expect(turn.reload.response).to eq("Hola.")
      answer
    end

    Concierge::Respond.call(turn:, agent:)
    Concierge::Respond.call(turn: turn.reload, agent:)

    expect(turn.reload).to have_attributes(state: "completed", response: answer[:content], input_tokens: 12, output_tokens: 9)
  end

  it "records a recoverable provider failure without treating it as success" do
    allow(agent).to receive(:call).and_raise(Concierge::ProviderUnavailable)
    Concierge::Respond.call(turn:, agent:)

    expect(turn.reload).to have_attributes(state: "failed", error_code: "provider_unavailable")
    expect(turn.retry!).to be(true)
    expect(turn.reload.state).to eq("queued")
  end

  it "rechecks an archived relationship before calling the provider" do
    profile = create(:relationship_profile, user:)
    conversation.update!(relationship_profile: profile)
    turn.update!(context: { relationship_profile_id: profile.id, relationship_mode: "personal" })
    profile.archive!

    expect(agent).not_to receive(:call)
    Concierge::Respond.call(turn:, agent:)
    expect(turn.reload.error_code).to eq("context_unavailable")
  end

  it "discards output when the relationship mode changes during generation" do
    profile = create(:relationship_profile, user:)
    conversation.update!(relationship_profile: profile)
    turn.update!(context: { relationship_profile_id: profile.id, relationship_mode: "personal" })
    allow(agent).to receive(:call) do
      profile.update!(relationship_mode: "professional")
      answer
    end

    Concierge::Respond.call(turn:, agent:)

    expect(turn.reload).to have_attributes(state: "failed", error_code: "context_unavailable", response: nil)
  end

  it "discards output when a tool source is revoked during generation" do
    profile = create(:relationship_profile, user:)
    note = profile.relationship_notes.create!(body: "Private after revocation", private: false)
    allow(agent).to receive(:call) do |turn:, token:|
      Concierge::Execute.call(turn:, token:, name: "notes.read", arguments: { id: note.id, relationship_profile_id: profile.id })
      note.update!(private: true)
      answer
    end

    Concierge::Respond.call(turn:, agent:)

    expect(turn.reload).to have_attributes(state: "failed", error_code: "context_unavailable", response: nil)
  end
end
