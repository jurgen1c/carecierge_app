require "rails_helper"

RSpec.describe "Conversational planning and reviews", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:, first_name: "Ana") }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Plan Ana's birthday", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  def execute(name, **arguments)
    Concierge::Execute.call(turn:, token:, name:, arguments: arguments.stringify_keys)
  end

  def allow_reminders(approval: false)
    user.automation_permissions.create!(capability: "send_reminders", relationship_profile: profile,
      mode: approval ? "ask_every_time" : "allow_automatically")
  end

  it "clears an existing task deadline and details through the advertised schema" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    task = create(:plan_task, event_plan: plan, due_on: Date.current, details: "Old detail", origin: "manual", source_context: [])
    operation = Concierge::Catalog.fetch("tasks.update")
    expect(operation.schema.fetch(:properties).fetch("due_on").fetch(:type)).to include("null")
    execute("tasks.update", event_plan_id: plan.id, id: task.id, due_on: nil, details: nil)
    expect(task.reload).to have_attributes(due_on: nil, details: nil)
  end

  it "creates a birthday plan with source provenance and keeps template edits when the date moves" do
    date = profile.important_dates.create!(date_type: "birthday", starts_on: "2026-10-20", recurrence: "yearly")
    result = execute("plans.create", title: "Ana's birthday", occasion_type: "birthday", starts_on: "2026-10-20", important_date_id: date.id)
    plan = user.event_plans.find(result.dig("record", "id"))
    expect(plan.source_context.sole).to include("id" => "important_date:#{date.id}", "role" => "birthday_origin")
    expect(plan.plan_tasks).not_to be_empty
    task = plan.plan_tasks.ordered.first
    execute("tasks.update", event_plan_id: plan.id, id: task.id, title: "Keep it small")
    execute("plans.update", id: plan.id, starts_on: "2026-10-21", guest_list: "Four close friends")
    expect(task.reload.title).to eq("Keep it small")
    expect(plan.reload.guest_list).to eq("Four close friends")
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "creates, completes, reopens, and confirms removal of a manual task" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    result = execute("tasks.create", event_plan_id: plan.id, title: "Choose a quiet place", phase: "decide", kind: "task")
    task = plan.plan_tasks.find(result.dig("record", "id"))
    execute("tasks.complete", event_plan_id: plan.id, id: task.id)
    expect(task.reload).to be_completed
    execute("tasks.reopen", event_plan_id: plan.id, id: task.id)
    expect(task.reload).not_to be_completed
    result = execute("tasks.destroy", event_plan_id: plan.id, id: task.id)
    expect(result["status"]).to eq("awaiting_approval")
    action = turn.actions.find(result["action_id"])
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(plan.plan_tasks.current).not_to include(task)
  end

  it "refuses a foreign date or task instead of attaching it to this plan" do
    other_date = create(:important_date)
    expect do
      execute("plans.create", title: "Birthday", occasion_type: "birthday", important_date_id: other_date.id)
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(user.event_plans).to be_empty
    other_task = create(:plan_task)
    own_plan = create(:event_plan, user:, relationship_profile: profile)
    expect do
      execute("tasks.update", event_plan_id: own_plan.id, id: other_task.id, title: "Wrong task")
    end.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "saves an owner-local reminder linked to a real commitment without duplicates" do
    allow_reminders
    commitment = create(:commitment, relationship_profile: profile)
    result = execute("reminders.create", title: "Call Dad", scheduled_at: "2026-10-02T09:00:00-06:00", commitment_id: commitment.id)
    reminder = user.reminders.find(result.dig("record", "id"))
    expect(reminder).to have_attributes(commitment_id: commitment.id, relationship_profile_id: profile.id)
    expect(reminder.scheduled_at).to eq(Time.iso8601("2026-10-02T15:00:00Z"))
    execute("reminders.create", title: "Call Dad", scheduled_at: "2026-10-02T09:00:00-06:00", commitment_id: commitment.id)
    expect(user.reminders.count).to eq(1)
    execute("reminders.snooze", id: reminder.id, until_time: 2.days.from_now.iso8601)
    expect(reminder.reload.snoozed_until).to be_present
    execute("reminders.complete", id: reminder.id)
    expect(reminder.reload).to be_completed
  end

  it "waits for required reminder approval and rechecks permission when decided" do
    allow_reminders(approval: true)
    result = execute("reminders.create", title: "Birthday follow-up", scheduled_at: 3.days.from_now.iso8601)
    expect(result["status"]).to eq("awaiting_approval")
    expect(user.reminders).to be_empty
    action = turn.actions.find(result["action_id"])
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(user.reminders.count).to eq(1)
  end

  it "denies disabled automation and inconsistent relationship source attachments" do
    expect do
      execute("reminders.create", title: "Call", scheduled_at: 3.days.from_now.iso8601)
    end.to raise_error(Concierge::PermissionDenied)
    allow_reminders
    other = create(:commitment, relationship_profile: create(:relationship_profile, user:))
    expect do
      execute("reminders.create", title: "Wrong relationship", scheduled_at: 3.days.from_now.iso8601, commitment_id: other.id)
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(user.reminders).to be_empty
  end

  it "reviews a proposal through the existing approval queue and canonical memory operation" do
    proposal = create(:extracted_memory, relationship_profile: profile, conversation_recap: create(:conversation_recap, relationship_profile: profile))
    listed = execute("proposals.search")
    expect(listed.fetch("records").sole).to include("review_status" => "pending", "certainty" => "inferred")
    result = execute("proposals.review", id: proposal.id, decision: "correct", corrected_title: "Tea", corrected_body: "Green tea")
    expect(profile.memory_records).to be_empty
    action = turn.actions.find(result["action_id"])
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(proposal.reload).to be_corrected
    expect(proposal.canonical_memory_record).to have_attributes(title: "Tea", body: "Green tea", source: "user_corrected")
    expect(user.approval_requests.where(subject: proposal)).to exist
  end

  it "keeps previously read reminders current when completing and reopening their plan" do
    allow_reminders
    plan = create(:event_plan, user:, relationship_profile: profile)
    created = execute("reminders.create", title: "Prepare the meeting", scheduled_at: 2.days.from_now.iso8601, event_plan_id: plan.id)
    reminder = user.reminders.find(created.fetch("record").fetch("id"))
    execute("plans.complete", id: plan.id)
    expect(plan.reload).to be_completed
    expect(reminder.reload).to be_completed
    expect(Concierge::History.sources_current?(turn)).to be(true)
    execute("plans.reopen", id: plan.id)
    expect(plan.reload).to be_active
    expect(reminder.reload).to be_completed
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "keeps an already read reminder current after its task is completed" do
    allow_reminders
    plan = create(:event_plan, user:, relationship_profile: profile)
    task = create(:plan_task, event_plan: plan)
    created = execute("reminders.create", title: "Prepare this task", scheduled_at: 2.days.from_now.iso8601, event_plan_id: plan.id, plan_task_id: task.id)
    reminder = user.reminders.find(created.fetch("record").fetch("id"))
    execute("tasks.complete", event_plan_id: plan.id, id: task.id)
    expect(task.reload).to be_completed
    expect(reminder.reload).to be_completed
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "requires a selected work vendor before linking its quote to a new reminder" do
    allow_reminders
    plan = create(:event_plan, user:, relationship_profile: profile)
    vendor = create(:vendor, user:)
    quote = create(:vendor_quote, user:, event_plan: plan, vendor:)
    profile.update!(relationship_mode: "professional", professional_context: { "event_plans" => [ plan.id ] })
    expect do
      execute("reminders.create", title: "Consider this quote", scheduled_at: 2.days.from_now.iso8601, event_plan_id: plan.id, vendor_quote_id: quote.id)
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(user.reminders).to be_empty
  end
end
