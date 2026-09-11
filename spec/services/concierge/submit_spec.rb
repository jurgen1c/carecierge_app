require "rails_helper"

RSpec.describe "Submitting concierge messages", type: :service do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:conversation) { ConciergeConversation.create!(user:) }
  let(:request_key) { SecureRandom.uuid }

  def submit(**options)
    Concierge::Submit.call(user:, conversation:, content: "Recuerda que Ana prefiere té", locale: "es", request_key:, **options)
  end

  it "persists the message before enqueueing a content-free job" do
    expect { submit }.to have_enqueued_job(ConciergeResponseJob).with(kind_of(String))
    turn = conversation.turns.sole
    expect(turn.content).to eq("Recuerda que Ana prefiere té")
    expect(turn.locale).to eq("es")
    expect(turn.state).to eq("queued")
  end

  it "reuses the same browser submission without a second job" do
    first = submit
    expect { submit }.not_to have_enqueued_job(ConciergeResponseJob)
    expect(submit).to eq(first)
    expect(conversation.turns.count).to eq(1)
  end

  it "rejects reuse of a request key for different content" do
    submit
    expect do
      Concierge::Submit.call(user:, conversation:, content: "Different request", locale: "es", request_key:)
    end.to raise_error(Concierge::RequestConflict)
  end

  it "rejects another account before saving or enqueueing" do
    expect do
      Concierge::Submit.call(user: create(:user), conversation:, content: "Read Ana", locale: "en", request_key:)
    end.to raise_error(Pundit::NotAuthorizedError)
    expect(conversation.turns).to be_empty
  end

  it "serializes new turns while an earlier request is queued" do
    submit
    expect do
      Concierge::Submit.call(user:, conversation:, content: "Next request", locale: "en", request_key: SecureRandom.uuid)
    end.to raise_error(Concierge::ConversationBusy)
  end

  it "releases an exhausted stalled turn while fencing late worker results" do
    Timecop.freeze do
      previous = submit
      previous.update!(state: "running", attempts: ConciergeTurn::MAX_ATTEMPTS,
        started_at: 6.minutes.ago, run_token: SecureRandom.uuid, response: "Incomplete")
      token = previous.run_token
      next_turn = Concierge::Submit.call(user:, conversation:, content: "Next request", locale: "en", request_key: SecureRandom.uuid)
      expect(next_turn.state).to eq("queued")
      expect(previous.reload).to have_attributes(state: "failed", run_token: nil, response: nil, error_code: "execution_expired")
      expect(previous.finish!(token:, response: "Late result")).to be(false)
      expect(previous.retry!).to be(false)
    end
  end

  it "keeps a live final attempt and a retryable stalled attempt exclusive" do
    Timecop.freeze do
      previous = submit
      previous.update!(state: "running", attempts: ConciergeTurn::MAX_ATTEMPTS, started_at: Time.current, run_token: SecureRandom.uuid)
      expect { Concierge::Submit.call(user:, conversation:, content: "Next", locale: "en", request_key: SecureRandom.uuid) }
        .to raise_error(Concierge::ConversationBusy)
      previous.update!(attempts: 2, started_at: 6.minutes.ago)
      expect { Concierge::Submit.call(user:, conversation:, content: "Next", locale: "en", request_key: SecureRandom.uuid) }
        .to raise_error(Concierge::ConversationBusy)
    end
  end

  it "captures relationship mode from the owned record rather than submitted context" do
    profile = create(:relationship_profile, user:, relationship_mode: "professional")
    conversation.update!(relationship_profile: profile)
    turn = submit(context: { "relationship_mode" => "personal", "private_note_ids" => [] })

    expect(turn.context).to include("relationship_profile_id" => profile.id, "relationship_mode" => "professional")
  end

  it "does not accept a private note selected from another relationship" do
    profile = create(:relationship_profile, user:)
    conversation.update!(relationship_profile: profile)
    note = create(:relationship_note, private: true)

    expect { submit(context: { "private_note_ids" => [ note.id ] }) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "requires an active lease for selected vault data" do
    profile = create(:relationship_profile, user:)
    conversation.update!(relationship_profile: profile)

    expect { submit(context: { "vault_item_ids" => [ SecureRandom.uuid ] }) }.to raise_error(Concierge::VaultLocked)
  end
end
