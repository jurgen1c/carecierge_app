require "rails_helper"

RSpec.describe "Conversational person clarification", type: :service do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:ana) { create(:relationship_profile, user:, first_name: "Ana", last_name: "Ruiz", preferred_name: nil) }
  let(:other_ana) { create(:relationship_profile, user:, first_name: "Ana", last_name: "Vega", preferred_name: nil) }
  let(:conversation) { ConciergeConversation.create!(user:) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Remember Ana likes quiet places", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  def choices
    result = Concierge::Execute.call(turn:, token:, name: "people.clarify", arguments: { ids: [ ana.id, other_ana.id ] })
    turn.finish!(token:, response: "Which Ana?")
    turn.actions.find(result.fetch("action_id"))
  end

  it "resumes the unanswered request with the chosen authorized context exactly once" do
    action = choices
    expect do
      Concierge::Clarify.call(user:, action:, relationship_profile_id: ana.id)
    end.to have_enqueued_job(ConciergeResponseJob).once
    resumed = conversation.turns.where.not(id: turn.id).sole
    expect(resumed).to have_attributes(content: turn.content, locale: "en")
    expect(resumed.context).to include("relationship_profile_id" => ana.id, "private_note_ids" => [], "vault_item_ids" => [])
    expect(conversation.reload.relationship_profile_id).to eq(ana.id)
    expect { Concierge::Clarify.call(user:, action: action.reload, relationship_profile_id: ana.id) }.not_to have_enqueued_job
    expect(conversation.turns.count).to eq(2)
    expect { Concierge::Clarify.call(user:, action: action.reload, relationship_profile_id: other_ana.id) }.to raise_error(Concierge::RequestConflict)
  end

  it "rejects a person outside the saved choices and rejects another owner" do
    action = choices
    unlisted = create(:relationship_profile, user:)
    expect { Concierge::Clarify.call(user:, action:, relationship_profile_id: unlisted.id) }.to raise_error(ActiveRecord::RecordNotFound)
    expect { Concierge::Clarify.call(user: create(:user), action:, relationship_profile_id: ana.id) }.to raise_error(Pundit::NotAuthorizedError)
    expect(conversation.reload.relationship_profile_id).to be_nil
    expect(conversation.turns.count).to eq(1)
  end

  it "does not replay a request that already performed a mutation" do
    Concierge::Execute.call(turn:, token:, name: "memories.create", arguments: { relationship_profile_id: ana.id, title: "Quiet", body: "Likes quiet places" })
    action = choices
    expect(Concierge::Clarify.available?(action:)).to be(false)
    expect { Concierge::Clarify.call(user:, action:, relationship_profile_id: ana.id) }.to raise_error(Concierge::RequestConflict)
    expect(ana.memory_records.count).to eq(1)
  end

  it "withdraws choices after a new message or a person edit" do
    action = choices
    Timecop.freeze do
      ana.update!(last_name: "Changed")
      expect(Concierge::Clarify.available?(action:)).to be(false)
      expect { Concierge::Clarify.call(user:, action:, relationship_profile_id: ana.id) }.to raise_error(Concierge::RequestConflict)
    end
    conversation.turns.create!(request_key: SecureRandom.uuid, content: "Never mind", locale: "en", state: "completed", created_at: 1.second.from_now)
    expect(Concierge::Clarify.available?(action:)).to be(false)
  end
end
