require "rails_helper"

RSpec.describe "Concierge individual operation tools" do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) do
    conversation.turns.create!(content: "Remember this", locale: "en", request_key: SecureRandom.uuid,
      context: Concierge::Context.capture(user:, conversation:))
  end

  it "requires a looked-up relationship ID when a relationship-bound tool has no selected person" do
    conversation.update!(relationship_profile: nil)
    tool = Concierge::Tool.new(operation: Concierge::Catalog.fetch("memories.create"), turn:, token: nil)

    expect(tool.params_schema.fetch(:required)).to include("relationship_profile_id")
    expect(tool.params_schema.dig(:properties, "relationship_profile_id", :description)).to include("people_search")
  end

  %w[gifts.create gift_ideas.generate gift_boxes.create gift_purchases.read work.read shortlists.search].each do |name|
    it "requires an explicit person for #{name} when its handler delegates scope resolution" do
      conversation.update!(relationship_profile: nil)
      tool = Concierge::Tool.new(operation: Concierge::Catalog.fetch(name), turn:, token: nil)
      expect(tool.params_schema.fetch(:required)).to include("relationship_profile_id")
    end
  end

  it "allows owner-wide reviews and plan-derived task scope without an extra person ID" do
    conversation.update!(relationship_profile: nil)
    %w[approvals.search tasks.search].each do |name|
      tool = Concierge::Tool.new(operation: Concierge::Catalog.fetch(name), turn:, token: nil)
      expect(tool.params_schema.fetch(:required)).not_to include("relationship_profile_id")
    end
  end

  it "preserves implicit selected-person context and optional global reminder scope" do
    tool = Concierge::Tool.new(operation: Concierge::Catalog.fetch("memories.create"), turn:, token: nil)
    expect(tool.params_schema.fetch(:required)).not_to include("relationship_profile_id")
    conversation.update!(relationship_profile: nil)
    reminder = Concierge::Tool.new(operation: Concierge::Catalog.fetch("reminders.create"), turn:, token: nil)
    expect(reminder.params_schema.fetch(:required)).not_to include("relationship_profile_id")
  end

  it "exposes each exact operation schema while retaining authorization and domain results" do
    tools = Concierge::Catalog.tools(turn:, token: turn.claim!)
    expect(tools.map(&:name).uniq.size).to eq(Concierge::Catalog.all.size)
    tool = tools.find { |candidate| candidate.name == "memories_create" }
    expect(tool.params_schema.fetch(:required)).to include("title", "body")
    expect(tool.description).to include("explicitly asks to remember")
    expect(RubyLLM).not_to receive(:logger)
    result = tool.call("title" => "Tea", "body" => "Green tea")
    expect(result).to include("status" => "succeeded")
    expect(profile.memory_records.sole.body).to eq("Green tea")
    expect(tool.call("title" => "Tea")).to include("status" => "invalid_arguments")
    expect(tool.call("action" => "people.create", "arguments" => {})).to include("status" => "invalid_arguments")
    expect(tool.call("title" => "Tea", "body" => "Tea", "user_id" => user.id)).to include("status" => "invalid_arguments")
    expect(profile.memory_records.count).to eq(1)
  end
end
