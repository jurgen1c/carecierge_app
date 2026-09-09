require "rails_helper"

RSpec.describe "Professional concierge scope", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:, relationship_mode: "professional") }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Prepare a work follow-up", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  def execute(name, arguments = {})
    Concierge::Execute.call(turn:, token:, name:, arguments:)
  end

  it "never includes personal interaction timing in professional cadence reads or saves" do
    create(:interaction, relationship_profile: profile, occurred_at: 2.days.ago)
    profile.create_contact_cadence!(interval_days: 14)
    %w[read save].each do |operation|
      arguments = operation == "save" ? { interval_days: 30 } : {}
      record = execute("cadence.#{operation}", arguments).fetch("record")
      expect(record).not_to have_key("last_interaction_at")
    end
    create(:interaction, relationship_profile: profile, occurred_at: 1.day.ago)
    expect(Concierge::History.sources_current?(turn.reload)).to be(true)
  end

  it "rejects personal-memory writes before mutation even if the model knows a valid owned ID" do
    memory = profile.memory_records.create!(title: "Personal", body: "Private detail")
    expect { execute("memories.update", { id: memory.id, body: "Work detail" }) }.to raise_error(Concierge::ContextUnavailable)
    expect(memory.reload.body).to eq("Private detail")
    expect { execute("memories.create", { title: "Personal", body: "Another detail" }) }.to raise_error(Concierge::ContextUnavailable)
    expect(profile.memory_records.count).to eq(1)
  end

  it "rejects unsupported personal collection creation before records or side effects exist" do
    expect { execute("moods.create", { category: MoodNote::CATEGORIES.first, observation: "Seems calm", observed_at: "2026-09-08T10:00:00Z" }) }.to raise_error(Concierge::ContextUnavailable)
    expect(profile.mood_notes).to be_empty
    expect(profile.timeline_entries).to be_empty
    expect(profile.interactions).to be_empty
  end

  it "does not let a professional conversation read another person's personal records" do
    other = create(:relationship_profile, user:)
    memory = other.memory_records.create!(title: "Personal", body: "Private detail")
    expect { execute("memories.read", { id: memory.id, relationship_profile_id: other.id }) }.to raise_error(Concierge::ContextUnavailable)
  end

  %w[read update complete snooze destroy].each do |operation|
    it "rejects #{operation} of an unselected global reminder in a professional turn" do
      create(:automation_permission, user:, capability: "send_reminders", mode: "allow_automatically")
      reminder = user.reminders.create!(title: "Personal follow-up", scheduled_at: 2.days.from_now)
      version = Concierge::RecordVersion.for(reminder)
      arguments = { "id" => reminder.id }
      arguments["title"] = "Changed through work" if operation == "update"
      arguments["until_time"] = 3.days.from_now.iso8601 if operation == "snooze"
      expect { execute("reminders.#{operation}", arguments) }.to raise_error(Concierge::ContextUnavailable)
      expect(Concierge::RecordVersion.for(reminder.reload)).to eq(version)
      expect(turn.actions).to be_empty
    end
  end

  it "omits personal birthdays from people searches in a professional conversation" do
    create(:relationship_profile, user:, first_name: "Ana", birthday: "1990-01-02")
    profile.update!(first_name: "Ana", birthday: "1991-02-03")
    records = execute("people.search", { query: "Ana" }).fetch("records")
    expect(records).not_to be_empty
    expect(records.any? { |record| record.key?("birthday") }).to be(false)
  end

  it "keeps selected work notes public when editing through chat" do
    note = profile.relationship_notes.create!(category: "Work", body: "Agenda", private: false)
    profile.update!(professional_context: { "relationship_notes" => [ note.id ] })
    expect { execute("notes.update", { id: note.id, private: true }) }.to raise_error(Concierge::ContextUnavailable)
    expect(note.reload).not_to be_private
  end

  it "adds a newly requested work note to explicit work context without including existing personal notes" do
    personal = profile.relationship_notes.create!(category: "Personal", body: "Personal detail", private: false)
    result = execute("notes.create", { category: "Work", body: "Discuss the new project" })
    note = profile.relationship_notes.find(result.fetch("record").fetch("id"))
    expect(profile.reload.work_context.selected("relationship_notes").pluck(:id)).to eq([ note.id ])
    expect(profile.work_context.selected("relationship_notes")).not_to include(personal)
    expect(Concierge::Context.verify!(turn:)).to be(true)
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "refreshes a previously read profile after selecting a newly created work record" do
    execute("people.read", { id: profile.id })
    execute("notes.create", { category: "Work", body: "Discuss the new project" })
    expect { Concierge::Respond.verify_response!(turn.reload) }.not_to raise_error
    execute("commitments.create", { title: "Send the agenda" })
    expect { Concierge::Respond.verify_response!(turn.reload) }.not_to raise_error
    profile.reload.update!(first_name: "Changed elsewhere")
    expect(Concierge::History.sources_current?(turn.reload)).to be(false)
  end

  it "refuses a seventh work source before creating an orphaned record or replacing existing selections" do
    notes = 6.times.map { |index| profile.relationship_notes.create!(category: "Work", body: "Detail #{index}", private: false) }
    profile.update!(professional_context: { "relationship_notes" => notes.map(&:id) })
    expect { execute("notes.create", { category: "Work", body: "Seventh" }) }.to raise_error(Concierge::ContextUnavailable)
    expect(profile.relationship_notes.count).to eq(6)
    expect(profile.reload.professional_context.fetch("relationship_notes")).to match_array(notes.map(&:id))
  end

  it "drops unavailable old selections when adding a new work record" do
    note = profile.relationship_notes.create!(category: "Work", body: "Old agenda", private: false)
    profile.update!(professional_context: { "relationship_notes" => [ note.id ] })
    note.destroy!
    result = execute("notes.create", { category: "Work", body: "New agenda" })
    expect(profile.reload.professional_context.fetch("relationship_notes")).to eq([ result.fetch("record").fetch("id") ])
    expect(Concierge::Context.verify!(turn:)).to be(true)
  end

  it "reviews exact work boundaries before changing them and keeps selected records" do
    note = profile.relationship_notes.create!(category: "Work", body: "Agenda", private: false)
    profile.update!(professional_context: { "organization" => "Studio", "relationship_notes" => [ note.id ] })
    result = execute("work.update", { boundaries: "No gifts above 25 dollars", gifts_allowed: true })
    expect(result).to include("status" => "awaiting_approval")
    expect(profile.reload.professional_context).not_to have_key("boundaries")
    action = turn.actions.find(result.fetch("action_id"))
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(profile.reload.professional_context).to include("boundaries" => "No gifts above 25 dollars", "gifts_allowed" => "1", "relationship_notes" => [ note.id ])
    expect(Concierge::Context.verify!(turn: turn.reload)).to be(true)
    expect(execute("work.read").fetch("record")).to include("organization" => "Studio", "gifts_allowed" => true)
  end

  it "records an explicitly requested suitable work gift without importing existing personal gifts" do
    personal = create(:gift, relationship_profile: profile, name: "Personal present")
    profile.update!(professional_context: { "gifts_allowed" => "1", "boundaries" => "Office stationery only" })
    result = execute("gifts.create", { name: "Notebook", notes: "Office stationery", price_cents: 1000 })
    gift = profile.gifts.find(result.fetch("record").fetch("id"))
    expect(profile.reload.work_context.selected("gifts").pluck(:id)).to eq([ gift.id ])
    expect(execute("gifts.search").fetch("records").pluck("id")).to eq([ gift.id ])
    expect { execute("gifts.read", { id: personal.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    execute("gifts.mark_given", { id: gift.id, given_on: "2026-09-08", outcome: "successful" })
    expect(gift.reload.status).to eq("given")
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "rejects gift mutations while work gifts are disabled" do
    expect { execute("gifts.create", { name: "Notebook" }) }.to raise_error(Concierge::PermissionDenied)
    expect(profile.gifts).to be_empty
  end

  it "manages an explicitly requested work plan, its tasks and a linked reminder without importing older plans" do
    older = create(:event_plan, user:, relationship_profile: profile, title: "Personal dinner")
    create(:automation_permission, user:, capability: "send_reminders", mode: "allow_automatically")
    result = execute("plans.create", { title: "Work review dinner", occasion_type: "custom", starts_on: "2026-10-01" })
    plan = profile.event_plans.find(result.fetch("record").fetch("id"))
    expect(profile.reload.work_context.selected("event_plans").pluck(:id)).to eq([ plan.id ])
    expect(execute("plans.search").fetch("records").pluck("id")).to eq([ plan.id ])
    expect { execute("plans.read", { id: older.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    task_result = execute("tasks.create", { event_plan_id: plan.id, title: "Prepare the agenda", phase: "arrange", kind: "task", due_on: "2026-09-30" })
    task = plan.plan_tasks.find(task_result.fetch("record").fetch("id"))
    reminder_result = execute("reminders.create", { title: "Prepare the review agenda", scheduled_at: "2026-09-30T09:00:00-06:00", event_plan_id: plan.id, plan_task_id: task.id })
    reminder = user.reminders.find(reminder_result.fetch("record").fetch("id"))
    expect(profile.reload.work_context.selected("reminders").pluck(:id)).to eq([ reminder.id ])
    expect(execute("reminders.read", { id: reminder.id }).fetch("record")).to include("plan_task_id" => task.id)
    execute("tasks.complete", { event_plan_id: plan.id, id: task.id })
    expect(task.reload).to be_completed
  end

  it "limits work reminders to selected records and refuses unselected source links before persistence" do
    personal = create(:reminder, user:, relationship_profile: profile, title: "Personal reminder")
    commitment = profile.commitments.create!(title: "Personal promise")
    create(:automation_permission, user:, capability: "send_reminders", mode: "allow_automatically")
    expect(execute("reminders.search").fetch("records")).to be_empty
    expect { execute("reminders.read", { id: personal.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    expect do
      execute("reminders.create", { title: "Call", scheduled_at: "2026-09-30T09:00:00-06:00", commitment_id: commitment.id })
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(user.reminders.count).to eq(1)
    result = execute("reminders.create", { title: "Prepare review", scheduled_at: "2026-09-30T09:00:00-06:00" })
    reminder = user.reminders.find(result.fetch("record").fetch("id"))
    expect(execute("reminders.search").fetch("records").pluck("id")).to eq([ reminder.id ])
    expect(Concierge::History.sources_current?(turn)).to be(true)
    execute("reminders.complete", { id: reminder.id })
    expect(reminder.reload).to be_completed
  end

  it "excludes an old task's unselected personal evidence even when the owner selects its plan for work" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    memory = profile.memory_records.create!(title: "Personal detail", body: "Private life")
    task = plan.plan_tasks.create!(title: "Personal suggestion", details: "Private life", phase: "decide", kind: "task", origin: "ai", position: 0,
      source_context: [ { "id" => "memory:#{memory.id}", "label" => "Personal detail", "sensitive" => false, "certainty" => "confirmed" } ])
    profile.update!(professional_context: { "event_plans" => [ plan.id ] })
    expect(execute("tasks.search", { event_plan_id: plan.id }).fetch("records")).to be_empty
    expect { execute("tasks.read", { event_plan_id: plan.id, id: task.id }) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "prepares a suitable selected work gift and adds its purchase task only to a selected work plan" do
    profile.update!(professional_context: { "gifts_allowed" => "1", "boundaries" => "Office stationery only" })
    gift_id = execute("gifts.create", { name: "Notebook" }).fetch("record").fetch("id")
    execute("gift_purchases.save", { gift_id:, version: "new", budget: "25.00", currency: "USD", purchase_by: "2026-09-30" })
    plan_id = execute("plans.create", { title: "Team review", occasion_type: "custom" }).fetch("record").fetch("id")
    result = execute("gift_purchases.add_task", { gift_id:, event_plan_id: plan_id })
    task = profile.gifts.find(gift_id).purchase_plan.current_plan_task
    expect(task.event_plan_id).to eq(plan_id)
    expect(result.fetch("records").pluck("id")).to include(task.id)
    expect(Concierge::History.sources_current?(turn)).to be(true)
    expect(ExternalProviderAction.count).to eq(0)
  end

  it "manages a new work gift box without importing existing personal boxes or companion evidence" do
    old = profile.gift_boxes.create!(name: "Personal birthday", occasion: "Birthday")
    profile.update!(professional_context: { "gifts_allowed" => "1", "boundaries" => "Office stationery only" })
    create(:automation_permission, user:, capability: "send_reminders", mode: "allow_automatically")
    result = execute("gift_boxes.create", { name: "Office welcome", occasion: "New role", budget: "25.00" })
    box = profile.gift_boxes.find(result.fetch("record").fetch("id"))
    expect(profile.reload.work_context.selected("gift_boxes").pluck(:id)).to eq([ box.id ])
    expect { execute("gift_boxes.read", { id: old.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    execute("gift_boxes.add_item", { id: box.id, lock_version: box.lock_version, name: "Notebook", cost: "10.00" })
    expect(box.items.sole.name).to eq("Notebook")
    expect(execute("gift_boxes.suggest_companions", { id: box.id }).fetch("suggestions")).to be_empty
    execute("gift_boxes.remind", { id: box.id, scheduled_at: "2026-09-30T09:00:00-06:00" })
    expect(profile.reload.work_context.selected("reminders").pluck(:id)).to eq([ user.reminders.sole.id ])
    expect(Concierge::History.sources_current?(turn)).to be(true)
    expect(ExternalProviderAction.count).to eq(0)
  end
end
