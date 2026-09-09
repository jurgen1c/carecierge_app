require "rails_helper"

RSpec.describe "Retrying concierge work", type: :service do
  include ActiveJob::TestHelper
  let(:user) { create(:user) }
  let(:conversation) { ConciergeConversation.create!(user:) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Remember tea", locale: "en") }

  it "enqueues exactly once and never retries a failed message alongside another active message" do
    turn.fail!(token: turn.claim!)
    expect { Concierge::Retry.call(user:, turn:) }.to have_enqueued_job(ConciergeResponseJob).with(turn.id).exactly(:once)
    expect { Concierge::Retry.call(user:, turn:) }.not_to have_enqueued_job(ConciergeResponseJob)
    turn.fail!(token: turn.claim!)
    conversation.turns.create!(request_key: SecureRandom.uuid, content: "New question", locale: "en")
    expect { Concierge::Retry.call(user:, turn:) }.to raise_error(Concierge::ConversationBusy)
    expect(turn.reload.state).to eq("failed")
  end

  it "cannot retry someone else's request" do
    expect { Concierge::Retry.call(user: create(:user), turn:) }.to raise_error(Pundit::NotAuthorizedError)
  end
end
