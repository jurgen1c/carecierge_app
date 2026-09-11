require "rails_helper"

RSpec.describe "Conversational record search", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:, first_name: "Jordan", last_name: "Smith", preferred_name: nil) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Find my plans", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  def execute(name, arguments = {})
    Concierge::Execute.call(turn:, token:, name:, arguments:)
  end

  it "finds encrypted plan titles and task details within the owner's authorized records" do
    plan = create(:event_plan, user:, relationship_profile: profile, title: "Ana's birthday")
    task = plan.plan_tasks.create!(title: "Choose a place", details: "Quiet garden", phase: "decide", kind: "task", origin: "manual", position: 0)
    expect(execute("plans.search", { query: "birthday" }).fetch("records").sole).to include("id" => plan.id)
    expect(execute("tasks.search", { event_plan_id: plan.id, query: "garden" }).fetch("records").sole).to include("id" => task.id)
  end

  it "searches the visible text of a note while excluding unselected private notes" do
    note = profile.relationship_notes.create!(category: "Conversation", body: "Starts a new job on Monday", private: false)
    profile.relationship_notes.create!(category: "Private", body: "Secret job detail", private: true)
    expect(execute("notes.search", { query: "job" }).fetch("records").map { |record| record["id"] }).to eq([ note.id ])
  end

  it "returns an explicit next page without losing older matches" do
    21.times { |index| profile.commitments.create!(title: "Call #{index}") }
    first = execute("commitments.search", { query: "Call", page: 1 })
    second = execute("commitments.search", { query: "Call", page: first.fetch("next_page") })
    expect(first.fetch("records").size).to eq(20)
    expect(second.fetch("records").size).to eq(1)
    expect(second["next_page"]).to be_nil
    expect((first["records"] + second["records"]).map { |record| record["id"] }.uniq.size).to eq(21)
  end

  it "requires regeneration for legacy AI tasks even when their cited private source is selected" do
    note = profile.relationship_notes.create!(category: "Private", body: "Private context", private: true)
    plan = create(:event_plan, user:, relationship_profile: profile)
    task = plan.plan_tasks.create!(title: "Private suggestion", details: "Private context", phase: "decide", kind: "task", origin: "ai", position: 0,
      source_context: [ { "id" => "private_note:#{note.id}", "label" => "Private note", "certainty" => "confirmed", "sensitive" => true } ])
    expect(execute("tasks.search", { event_plan_id: plan.id }).fetch("records")).to be_empty
    expect { execute("tasks.read", { event_plan_id: plan.id, id: task.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ note.id ] }))
    expect { execute("tasks.read", { event_plan_id: plan.id, id: task.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    allow_any_instance_of(EventPlans::LlmSuggester).to receive(:generate).and_return([
      { "title" => "Regenerated suggestion", "details" => "Private context", "phase" => "decide", "kind" => "task",
        "source_ids" => [ "private_note:#{note.id}" ], "due_on" => nil }
    ])
    result = execute("plan_ideas.generate", { event_plan_id: plan.id })
    generated_id = result.fetch("records").sole.fetch("id")
    expect(execute("tasks.read", { event_plan_id: plan.id, id: generated_id }).fetch("record")).to include("id" => generated_id)
  end

  it "reaches older matching people, saved memories and reminders without duplicate page entries" do
    21.times do |index|
      create(:relationship_profile, user:, first_name: "Ana", last_name: "Person #{index}", preferred_name: nil)
      profile.memory_records.create!(title: "Tea #{index}", body: "Green tea")
      user.reminders.create!(relationship_profile: profile, title: "Call #{index}", scheduled_at: 2.days.from_now)
    end
    { "people.search" => "Ana", "memories.search" => "Tea", "reminders.search" => "Call" }.each do |name, query|
      first = execute(name, { query:, page: 1 })
      second = execute(name, { query:, page: first.fetch("next_page") })
      expect(first.fetch("records").size).to eq(20)
      expect(second.fetch("records").size).to eq(1)
      expect(second["next_page"]).to be_nil
      expect((first["records"] + second["records"]).pluck("id").uniq.size).to eq(21)
    end
  end

  it "finds older encrypted gift boxes and vendor comparisons with explicit continuation" do
    21.times do |index|
      profile.gift_boxes.create!(name: "Garden #{index}", occasion: "Birthday", currency: "USD")
      user.vendor_shortlists.create!(relationship_profile: profile, title: "Garden comparison #{index}")
    end
    %w[gift_boxes.search shortlists.search].each do |name|
      first = execute(name, { query: "Garden", page: 1 })
      second = execute(name, { query: "Garden", page: first.fetch("next_page") })
      expect(first.fetch("records").size).to eq(20)
      expect(second.fetch("records").size).to eq(1)
      expect(second["next_page"]).to be_nil
    end
  end

  it "paginates saved vendor searches while retaining existing filters" do
    21.times { |index| create(:vendor, user:, name: "Garden #{index}", category: "restaurant") }
    create(:vendor, name: "Garden from another owner", category: "restaurant")
    first = execute("vendors.search", { query: "Garden", category: "restaurant", page: 1 })
    second = execute("vendors.search", { query: "Garden", category: "restaurant", page: first.fetch("next_page") })
    expect(first.fetch("records").size).to eq(20)
    expect(second.fetch("records").size).to eq(1)
    expect((first["records"] + second["records"]).pluck("id")).to match_array(user.vendors.pluck(:id))
  end

  it "reaches older generated gift ideas and eligible reviews" do
    21.times do |index|
      create(:gift_recommendation, user:, relationship_profile: profile, title: "Garden idea #{index}",
        source_context: [ { "id" => "profile:#{profile.id}", "label" => "Relationship", "certainty" => "confirmed", "sensitive" => false } ])
      profile.memory_records.create!(title: "Review #{index}", body: "Possible detail", source: "ai_inferred", confidence: "inferred")
    end
    %w[gift_ideas.search approvals.search].each do |name|
      first = execute(name, { page: 1 })
      second = execute(name, { page: first.fetch("next_page") })
      expect(first.fetch("records").size).to eq(20)
      expect(second.fetch("records").size).to eq(1)
      expect(second["next_page"]).to be_nil
    end
  end

  it "reads older source-free authored draft revisions in revision order and can restore one from a later page" do
    draft = create(:message_draft, user:, relationship_profile: profile)
    revisions = 21.times.map { |index| create(:draft_revision, message_draft: draft, position: index + 1, origin: "edited", context_categories: [], content: "Revision #{index + 1}") }
    first = execute("drafts.read", { page: 1 })
    second = execute("drafts.read", { page: first.fetch("next_page") })
    expect(first.fetch("records").pluck("revision")).to eq(21.downto(2).to_a)
    expect(second.fetch("records").pluck("id")).to eq([ revisions.first.id ])
    expect(second["next_page"]).to be_nil
    restored = execute("drafts.restore", { revision_id: revisions.first.id })
    expect(restored.fetch("record")).to include("body" => "Revision 1", "revision" => 22)
  end

  it "reaches later personal touches without changing the checklist order" do
    checklist = create(:personal_touch_checklist, relationship_profile: profile, event_plan: create(:event_plan, user:, relationship_profile: profile))
    items = 21.times.map { |index| create(:personal_touch_item, personal_touch_checklist: checklist, position: index, title: "Touch #{index}") }
    first = execute("touches.search", { checklist_id: checklist.id, page: 1 })
    second = execute("touches.search", { checklist_id: checklist.id, page: first.fetch("next_page") })
    expect(first.fetch("records").pluck("id")).to eq(items.first(20).map(&:id))
    expect(second.fetch("records").pluck("id")).to eq([ items.last.id ])
  end

  it "finds older manual quotes and bookings while keeping the plan scope" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    vendor = create(:vendor, user:)
    21.times do |index|
      create(:vendor_quote, user:, event_plan: plan, vendor:, scope_details: "Garden #{index}")
      create(:booking, user:, event_plan: plan, title: "Garden #{index}")
    end
    %w[quotes.search bookings.search].each do |name|
      first = execute(name, { event_plan_id: plan.id, query: "Garden", page: 1 })
      second = execute(name, { event_plan_id: plan.id, query: "Garden", page: first.fetch("next_page") })
      expect(first.fetch("records").size).to eq(20)
      expect(second.fetch("records").size).to eq(1)
      expect(second["next_page"]).to be_nil
      expect((first["records"] + second["records"]).pluck("id").uniq.size).to eq(21)
    end
  end

  it "reaches older briefings and extracted proposals" do
    21.times do |index|
      create(:relationship_briefing, user:, relationship_profile: profile, interaction_context: "Dinner #{index}", status: "saved", sections: [], context_categories: [])
      create(:extracted_memory, relationship_profile: profile, title: "Tea #{index}")
    end
    %w[briefings.search proposals.search].each do |name|
      first = execute(name, { page: 1 })
      second = execute(name, { page: first.fetch("next_page") })
      expect(first.fetch("records").size).to eq(20)
      expect(second.fetch("records").size).to eq(1)
      expect(second["next_page"]).to be_nil
    end
  end
end
