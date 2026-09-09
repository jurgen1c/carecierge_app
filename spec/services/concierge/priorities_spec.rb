require "rails_helper"

RSpec.describe "Concierge follow-up priorities", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "What should I follow up on this week?", locale: "en") }
  let(:token) { turn.claim! }

  def execute(name, **arguments)
    Concierge::Execute.call(turn:, token:, name:, arguments: arguments.stringify_keys)
  end

  it "returns real owner-scoped priorities and hides a card without completing its source" do
    commitment = create(:commitment, relationship_profile: profile, title: "Call Dad", due_on: Date.current)
    create(:commitment, title: "Someone else's promise", due_on: Date.current)
    result = execute("priorities.search")
    entry = result.fetch("records").find { |record| record["id"] == commitment.id }
    expect(entry).to include("title" => "Call Dad", "section" => "later_today", "item_key" => "commitment:#{commitment.id}")
    expect(result.to_json).not_to include("Someone else's promise")

    execute("priorities.dismiss", item_key: entry.fetch("item_key"))
    expect(commitment.reload.status).to eq("open")
    expect(user.feed_item_states.sole.dismissed_at).to be_present
    expect(execute("priorities.search").fetch("records").map { |record| record["id"] }).not_to include(commitment.id)
  end

  %w[dismiss snooze].each do |event|
    it "includes authorized authored draft priorities and permits #{event}" do
      draft = create(:message_draft, user:, relationship_profile: profile)
      revision = create(:draft_revision, message_draft: draft, context_categories: [], origin: "edited")
      result = execute("priorities.search")
      entry = result.fetch("records").find { |record| record["item_key"] == "message_draft:#{draft.id}" }
      expect(entry).to include("record_type" => "DraftRevision", "id" => revision.id)
      execute("priorities.#{event}", item_key: entry.fetch("item_key"))
      expect(Concierge::History.sources_current?(turn.reload)).to be(true)
      expect(user.feed_item_states.sole.item_key).to eq(entry.fetch("item_key"))
    end
  end

  it "rejects foreign sources and excludes unselected professional commitments" do
    other = create(:commitment)
    expect { execute("priorities.snooze", item_key: "commitment:#{other.id}") }.to raise_error(ActiveRecord::RecordNotFound)
    profile.update!(relationship_mode: "professional")
    commitment = create(:commitment, relationship_profile: profile, title: "Unselected personal promise", due_on: Date.current)
    expect(execute("priorities.search").fetch("records").map { |record| record["id"] }).not_to include(commitment.id)
  end
end
