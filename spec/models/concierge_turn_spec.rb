require "rails_helper"

# == Schema Information
#
# Table name: concierge_turns
# Database name: primary
#
#  id              :uuid             not null, primary key
#  attempts        :integer          default(0), not null
#  content         :text             not null
#  context         :text
#  error_code      :string
#  finished_at     :datetime
#  input_tokens    :integer          default(0), not null
#  locale          :string           default("en"), not null
#  output_tokens   :integer          default(0), not null
#  request_key     :string(64)       not null
#  response        :text
#  run_token       :uuid
#  started_at      :datetime
#  state           :string           default("queued"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  conversation_id :uuid             not null
#
# Indexes
#
#  idx_concierge_turns_history                               (conversation_id,created_at,id)
#  index_concierge_turns_on_conversation_id_and_request_key  (conversation_id,request_key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (conversation_id => concierge_conversations.id)
#
RSpec.describe "Concierge turn lifecycle", type: :model do
  let(:conversation) { ConciergeConversation.create!(user: create(:user)) }

  it "requires a nonempty bounded message and a supported language" do
    turn = conversation.turns.new(request_key: SecureRandom.uuid, content: "", locale: "fr")
    expect(turn).not_to be_valid
    expect(turn.errors.attribute_names).to include(:content, :locale)

    turn.assign_attributes(content: "x" * 8_001, locale: "es")
    expect(turn).not_to be_valid
  end

  it "deduplicates the browser request key within the conversation" do
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Remember Ana likes tea", locale: "en")

    duplicate = conversation.turns.new(request_key: turn.request_key, content: turn.content, locale: "en")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:request_key]).to be_present
  end

  it "claims queued work once and rejects stale workers after an explicit retry" do
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Hola", locale: "es")
    token = turn.claim!

    expect(token).to be_present
    expect(turn.claim!).to be_nil
    expect(turn.finish!(token:, response: "Hola Ana")).to be(true)
    expect(turn.reload.state).to eq("completed")
    expect(turn.finish!(token: SecureRandom.uuid, response: "Wrong worker")).to be(false)
    expect(turn.reload.response).to eq("Hola Ana")
  end

  it "encrypts results and enforces one action fingerprint per turn" do
    turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Remember tea", locale: "en")
    action = turn.actions.create!(name: "memories.create", fingerprint: "a" * 64,
      arguments: { "body" => "Ana likes tea" }, result: { "title" => "Tea" })

    expect(action.reload.arguments).to eq("body" => "Ana likes tea")
    expect(action.arguments_before_type_cast).not_to include("Ana")
    expect(turn.actions.new(name: action.name, fingerprint: action.fingerprint)).not_to be_valid
  end

  it "recovers abandoned queue entries and expired workers with a fresh execution token" do
    Timecop.freeze do
      turn = conversation.turns.create!(request_key: SecureRandom.uuid, content: "Remember tea", locale: "en")
      expect(turn.retry!).to be(false)
      Timecop.travel(6.minutes.from_now) do
        expect(turn).to be_stalled
        expect(turn.retry!).to be(true)
        expect(turn).not_to be_stalled
        previous = turn.claim!
        Timecop.travel(6.minutes.from_now) do
          expect(turn.retry!).to be(true)
          current = turn.claim!
          expect(current).not_to eq(previous)
          expect(turn.append_response!(token: previous, text: "Stale answer")).to be(false)
        end
      end
    end
  end
end
