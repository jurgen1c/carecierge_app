require "rails_helper"

RSpec.describe "Conversational event suggestions", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:plan) { create(:event_plan, user:, relationship_profile: profile) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Suggest thoughtful steps for this plan", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  def generate
    Concierge::Execute.call(turn:, token:, name: "plan_ideas.generate", arguments: { event_plan_id: plan.id })
  end

  def ideas
    [ { "title" => "Choose a quiet place", "details" => "Consider a garden table", "phase" => "decide", "kind" => "task",
        "source_ids" => [ "profile:#{profile.id}" ], "due_on" => nil } ]
  end

  it "adds source-backed suggestions to the existing plan once without changing manual tasks" do
    task = plan.plan_tasks.create!(title: "Keep this task", phase: "decide", kind: "task", origin: "manual", position: 0)
    expect_any_instance_of(EventPlans::LlmSuggester).to receive(:generate).once.and_return(ideas)
    result = generate
    expect(result).to include("status" => "succeeded")
    expect { generate }.not_to change(PlanTask, :count)
    expect(task.reload.title).to eq("Keep this task")
    generated = plan.plan_tasks.where(origin: "ai").sole
    expect(generated.source_context.sole).to include("id" => "profile:#{profile.id}")
    expect(result.fetch("records").sole).to include("id" => generated.id, "certainty" => "inferred")
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "requires every uncited private generation input for later task reuse and fails closed after chat deletion" do
    note = profile.relationship_notes.create!(body: "Private garden detail", private: true)
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ note.id ] }))
    allow_any_instance_of(EventPlans::LlmSuggester).to receive(:generate).and_return(ideas)
    expect(generate).to include("status" => "succeeded")
    task = plan.plan_tasks.where(origin: "ai").sole
    expect(Concierge::OccasionSources.task_visible?(task, turn:)).to be(true)
    other_conversation = ConciergeConversation.create!(user:, relationship_profile: profile)
    other_turn = other_conversation.turns.create!(request_key: SecureRandom.uuid, content: "Read the tasks", locale: "es",
      context: Concierge::Context.capture(user:, conversation: other_conversation))
    expect(Concierge::OccasionSources.task_visible?(task, turn: other_turn)).to be(false)
    other_turn.update!(context: Concierge::Context.capture(user:, conversation: other_conversation, selections: { "private_note_ids" => [ note.id ] }))
    expect(Concierge::OccasionSources.task_visible?(task, turn: other_turn)).to be(true)
    conversation.destroy!
    expect(Concierge::OccasionSources.task_visible?(task.reload, turn: other_turn)).to be(false)
  end

  it "withdraws a task when an uncited public generation input becomes private" do
    note = profile.relationship_notes.create!(body: "Garden detail", private: false)
    allow_any_instance_of(EventPlans::LlmSuggester).to receive(:generate).and_return(ideas)
    expect(generate).to include("status" => "succeeded")
    task = plan.plan_tasks.where(origin: "ai").sole
    note.update!(private: true)
    expect(Concierge::OccasionSources.task_visible?(task, turn:)).to be(false)
  end

  it "excludes private-derived existing tasks from a later unselected provider request" do
    note = profile.relationship_notes.create!(body: "Private garden detail", private: true)
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ note.id ] }))
    allow_any_instance_of(EventPlans::LlmSuggester).to receive(:generate).and_return(ideas)
    expect(generate).to include("status" => "succeeded")
    later = conversation.turns.create!(request_key: SecureRandom.uuid, content: "More ideas", locale: "en",
      context: Concierge::Context.capture(user:, conversation:))
    expect_any_instance_of(EventPlans::LlmSuggester).to receive(:generate) do |_generator, **arguments|
      expect(arguments.fetch(:plan_snapshot).existing_tasks).to be_empty
      expect(arguments.fetch(:sources).map(&:content)).not_to include("Private garden detail")
      ideas
    end
    result = Concierge::Execute.call(turn: later, token: later.claim!, name: "plan_ideas.generate", arguments: { event_plan_id: plan.id })
    expect(result).to include("status" => "succeeded")
    expect(Concierge::History.sources_current?(later)).to be(true)
  end

  it "requires an uncited vault input to remain selected and available" do
    item = create(:privacy_vault_item, relationship_profile: profile, suggestion_usage: "allowed")
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "vault_item_ids" => [ item.id ] },
      vault_lease: PrivacyVault::Lease.issue_for(user)))
    allow_any_instance_of(EventPlans::LlmSuggester).to receive(:generate).and_return(ideas)
    expect(generate).to include("status" => "succeeded")
    task = plan.plan_tasks.where(origin: "ai").sole
    expect(Concierge::OccasionSources.task_visible?(task, turn:)).to be(true)
    item.update!(suggestion_usage: "excluded")
    expect(Concierge::OccasionSources.task_visible?(task, turn:)).to be(false)
  end

  it "revalidates the complete prior-plan source ID after its underlying note becomes protected" do
    note = profile.relationship_notes.create!(body: "Garden detail", private: false)
    prior = create(:event_plan, user:, relationship_profile: profile, occasion_type: "anniversary", status: "completed")
    prior.plan_tasks.create!(title: "Garden detail", phase: "decide", kind: "task", origin: "manual", position: 0,
      source_context: [ { "id" => "public_note:#{note.id}", "label" => "Note", "sensitive" => false, "certainty" => "confirmed" } ])
    plan.update!(occasion_type: "anniversary", source_context: [ { "id" => "event_plan:#{prior.id}", "label" => "Prior plan", "role" => "prior_anniversary_context", "certainty" => "needs_confirmation" } ])
    source = EventPlans::ContextBuilder.new(event_plan: plan).call.sources.find { |item| item.kind == "prior_anniversary_plan" }
    reference = { "id" => source.id, "sensitive" => false }
    expect(Concierge::OccasionSources.sources_authorized?([ reference ], profile_id: profile.id, turn:, plan:)).to be(true)
    PrivacyVault::Protect.call(actor: user, protectable: note)
    expect(Concierge::OccasionSources.sources_authorized?([ reference ], profile_id: profile.id, turn:, plan:)).to be(false)
  end

  it "verifies shared task ancestors once per check and detects later changes and cycles" do
    newest = nil
    4.times do |round|
      step = conversation.turns.create!(request_key: SecureRandom.uuid, content: "More ideas", locale: "en",
        context: Concierge::Context.capture(user:, conversation:))
      allow_any_instance_of(EventPlans::LlmSuggester).to receive(:generate).and_return(
        2.times.map { |index| ideas.sole.merge("title" => "Round #{round} task #{index}") }
      )
      result = Concierge::Execute.call(turn: step, token: step.claim!, name: "plan_ideas.generate", arguments: { event_plan_id: plan.id })
      expect(result).to include("status" => "succeeded")
      newest = plan.plan_tasks.find(result.fetch("records").last.fetch("id"))
    end
    checks = 0
    counter = ->(_name, _start, _finish, _id, payload) { checks += 1 if payload[:sql].include?('FROM "concierge_actions"') && payload[:sql].include?("source_keys") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      expect(Concierge::TaskSources.input_visible?(newest, turn:)).to be(true)
    end
    expect(checks).to be <= plan.plan_tasks.count
    origin = conversation.turns.order(:created_at, :id).flat_map(&:actions).find { |action| action.result.fetch("records", []).any? { |record| record["id"] == newest.id } }
    value = origin.result.deep_dup
    value.fetch("task_generation_context").fetch("tasks") << { "id" => newest.id, "version" => Concierge::TaskSources.send(:input_version, newest) }
    origin.update!(result: value)
    expect(Concierge::TaskSources.input_visible?(newest, turn:)).to be(false)
  end

  it "retires a generated task dependency after editing an input while preserving the saved edit" do
    input = plan.plan_tasks.create!(title: "Choose a place", phase: "decide", kind: "task", origin: "manual", position: 0)
    allow_any_instance_of(EventPlans::LlmSuggester).to receive(:generate).and_return(ideas)
    generated_id = generate.fetch("records").sole.fetch("id")
    result = Concierge::Execute.call(turn:, token:, name: "tasks.update", arguments: { event_plan_id: plan.id, id: input.id, title: "Choose a different place" })
    expect(input.reload.title).to eq("Choose a different place")
    expect(result.fetch("superseded").pluck("id")).to include(generated_id)
    expect { Concierge::Respond.verify_response!(turn.reload) }.not_to raise_error
  end

  it "rolls suggestions back when the conversation disappears during the provider request" do
    allow_any_instance_of(EventPlans::LlmSuggester).to receive(:generate) do
      conversation.destroy!
      ideas
    end
    expect { generate }.not_to change(PlanTask, :count)
    expect(ConciergeAction.where(turn_id: turn.id)).to be_empty
  end

  it "fails the surviving action immediately when its plan becomes unavailable during generation" do
    allow_any_instance_of(EventPlans::LlmSuggester).to receive(:generate) do
      plan.reload.complete!
      ideas
    end
    expect do
      expect(generate).to include("status" => "failed", "error_code" => "context_unavailable")
    end.not_to change(PlanTask, :count)
    expect(turn.actions.sole).to have_attributes(state: "failed", run_token: nil, error_code: "context_unavailable")
  end

  it "uses selected work sources for a selected work plan and excludes old personal task content" do
    profile.update!(relationship_mode: "professional", professional_context: { "organization" => "Studio", "event_plans" => [ plan.id ] })
    personal = profile.memory_records.create!(title: "Personal detail", body: "Personal holiday")
    plan.plan_tasks.create!(title: "Personal holiday", phase: "decide", kind: "task", origin: "ai", position: 0,
      source_context: [ { "id" => "memory:#{personal.id}", "label" => "Personal", "sensitive" => false, "certainty" => "confirmed" } ])
    expect_any_instance_of(EventPlans::LlmSuggester).to receive(:generate) do |_generator, **arguments|
      expect(arguments.fetch(:sources).map(&:content).join(" ")).not_to include("Personal holiday")
      expect(arguments.fetch(:plan_snapshot).existing_tasks.map(&:title)).not_to include("Personal holiday")
      [ ideas.sole.merge("title" => "Review the agenda", "source_ids" => [ "professional:organization" ]) ]
    end
    result = generate
    expect(result.fetch("records").sole).to include("title" => "Review the agenda")
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end
end
