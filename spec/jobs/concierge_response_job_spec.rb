require "rails_helper"

RSpec.describe "Concierge response jobs", type: :job do
  it "safely discards a deleted turn without calling a provider" do
    expect(Concierge::Respond).not_to receive(:call)
    ConciergeResponseJob.perform_now(SecureRandom.uuid)
  end

  it "resolves persisted work and delegates the provider execution" do
    conversation = ConciergeConversation.create!(user: create(:user))
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Hello", locale: "en")

    expect(Concierge::Respond).to receive(:call).with(turn:)
    ConciergeResponseJob.perform_now(turn.id)
  end
end
