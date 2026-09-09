require "rails_helper"

RSpec.describe "Conversational backup plans and personal touches", type: :service do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }
  let(:plan) { create(:event_plan, user:, relationship_profile: profile) }
  let(:conversation) { ConciergeConversation.create!(user:, relationship_profile: profile) }
  let(:turn) { conversation.turns.create!(request_key: SecureRandom.uuid, content: "Plan for rain", locale: "en", context: Concierge::Context.capture(user:, conversation:)) }
  let(:token) { turn.claim! }

  def execute(name, arguments = {})
    Concierge::Execute.call(turn:, token:, name:, arguments:)
  end

  def stub_backup_generator(task:, source: "profile:#{profile.id}")
    allow_any_instance_of(BackupPlans::LlmGenerator).to receive(:generate).and_return(3.times.map do |index|
      { "title" => "Indoor option #{index + 1}", "summary" => "A small indoor gathering", "effort" => "low",
        "timing" => "same_day", "estimated_cost_cents" => 10000, "cost_level" => "similar", "relationship_fit" => "good",
        "preserved_constraints" => [ "Small guest list" ], "change_summary" => [ "Indoor venue" ],
        "replacement_task_ids" => [ task.id ], "source_ids" => [ source ],
        "tasks" => [ { "phase" => "arrange", "kind" => "backup_step", "title" => "Prepare indoors #{index + 1}",
          "details" => "Keep the same guest list", "due_on" => nil, "source_ids" => [ source ] } ] }
    end)
  end

  it "retires a read reminder changed by backup promotion" do
    task = create(:plan_task, event_plan: plan, title: "Outdoor setup")
    reminder = create(:reminder, user:, relationship_profile: profile, event_plan: plan, plan_task: task, scheduled_at: 2.days.from_now)
    execute("reminders.read", { id: reminder.id })
    stub_backup_generator(task:)
    execute("backups.generate", { event_plan_id: plan.id, scenario: "weather" })
    option = plan.backup_plans.sole.backup_options.first
    result = execute("backups.promote", { event_plan_id: plan.id, id: option.id })
    action = turn.actions.find(result.fetch("action_id"))
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(reminder.reload).to be_completed
    expect(reminder.plan_task_id).to be_nil
    expect(Concierge::History.sources_current?(turn.reload)).to be(true)
  end

  it "rejects work backup outputs that expose unselected linked reminders" do
    profile.update!(relationship_mode: "professional", professional_context: { "organization" => "Studio", "event_plans" => [ plan.id ] })
    task = create(:plan_task, event_plan: plan, title: "Prepare the room")
    create(:reminder, user:, relationship_profile: profile, event_plan: plan, plan_task: task,
      title: "Unselected private reminder", scheduled_at: 2.days.from_now)
    stub_backup_generator(task:, source: "professional:organization")
    result = execute("backups.generate", { event_plan_id: plan.id, scenario: "weather" })
    expect(result.to_json).not_to include("Unselected private reminder")
    expect(result.fetch("status")).to eq("failed")
    expect(plan.backup_plans).to be_empty
    backup = BackupPlans::Generate.call(actor: user, event_plan: plan, scenario: "weather", expected_relationship_mode: "professional", locale: :en)
    option = backup.backup_options.first
    expect(execute("backups.search", { event_plan_id: plan.id }).fetch("records")).to be_empty
    %w[read promote].each do |event|
      expect { execute("backups.#{event}", { event_plan_id: plan.id, id: option.id }) }.to raise_error(Concierge::ContextUnavailable)
    end
    expect(turn.actions.where(name: "backups.promote")).not_to exist
  end

  it "generates options once, previews a promotion, and preserves unrelated tasks" do
    task = create(:plan_task, event_plan: plan, title: "Outdoor setup")
    preserved = create(:plan_task, event_plan: plan, title: "Pick up the cake")
    stub_backup_generator(task:)
    result = execute("backups.generate", { event_plan_id: plan.id, scenario: "weather" })
    expect(result.fetch("records").size).to eq(3)
    expect { execute("backups.generate", { event_plan_id: plan.id, scenario: "weather" }) }.not_to change(BackupOption, :count)
    expect(task.reload).not_to be_superseded
    option = plan.backup_plans.sole.backup_options.first
    execute("backups.promote", { event_plan_id: plan.id, id: option.id })
    action = turn.actions.find_by!(name: "backups.promote")
    expect(action.state).to eq("awaiting_approval")
    expect(action.result.fetch("preview")).to include(option.title, "Outdoor setup")
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(task.reload).to be_superseded
    expect(preserved.reload).not_to be_superseded
    expect(plan.plan_tasks.current.pluck(:title)).to contain_exactly("Pick up the cake", "Prepare indoors 1")
    expect(Concierge::OccasionSources.task_visible?(plan.plan_tasks.where(backup_option: option).sole, turn:)).to be(true)
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "retains full private consent on promoted backup tasks even when their citations are public" do
    note = profile.relationship_notes.create!(body: "Private garden detail", private: true)
    turn.update!(context: Concierge::Context.capture(user:, conversation:, selections: { "private_note_ids" => [ note.id ] }))
    task = create(:plan_task, event_plan: plan)
    stub_backup_generator(task:)
    execute("backups.generate", { event_plan_id: plan.id, scenario: "weather" })
    option = plan.backup_plans.sole.backup_options.first
    result = execute("backups.promote", { event_plan_id: plan.id, id: option.id })
    action = turn.actions.find(result.fetch("action_id"))
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    generated = plan.plan_tasks.where(backup_option: option).sole
    expect(Concierge::OccasionSources.task_visible?(generated, turn:)).to be(true)
    other = ConciergeConversation.create!(user:, relationship_profile: profile)
    later = other.turns.create!(request_key: SecureRandom.uuid, content: "Read the plan", locale: "es",
      context: Concierge::Context.capture(user:, conversation: other))
    expect(Concierge::OccasionSources.task_visible?(generated, turn: later)).to be(false)
    later.update!(context: Concierge::Context.capture(user:, conversation: other, selections: { "private_note_ids" => [ note.id ] }))
    expect(Concierge::OccasionSources.task_visible?(generated, turn: later)).to be(true)
    conversation.destroy!
    expect(Concierge::OccasionSources.task_visible?(generated, turn: later)).to be(false)
  end

  it "retires prior backup references after a successful input-task edit" do
    task = create(:plan_task, event_plan: plan)
    stub_backup_generator(task:)
    ids = execute("backups.generate", { event_plan_id: plan.id, scenario: "weather" }).fetch("records").pluck("id")
    result = execute("tasks.update", { event_plan_id: plan.id, id: task.id, title: "Changed by the owner" })
    expect(result.fetch("superseded").pluck("id")).to include(*ids)
    expect(Concierge::History.sources_current?(turn.reload)).to be(true)
  end

  it "rejects promotion when the plan changes after the option was shown" do
    task = create(:plan_task, event_plan: plan)
    stub_backup_generator(task:)
    execute("backups.generate", { event_plan_id: plan.id, scenario: "weather" })
    execute("backups.promote", { event_plan_id: plan.id, id: plan.backup_plans.sole.backup_options.first.id })
    action = turn.actions.find_by!(name: "backups.promote")
    plan.increment!(:generation_version)
    expect { Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint) }.to raise_error(Concierge::RequestConflict)
    expect(task.reload).not_to be_superseded
  end

  it "generates and reviews a backup for an explicitly selected work plan" do
    profile.update!(relationship_mode: "professional", professional_context: { "organization" => "Studio", "event_plans" => [ plan.id ] })
    task = create(:plan_task, event_plan: plan, title: "Prepare the meeting room")
    reminder = create(:reminder, user:, relationship_profile: profile, event_plan: plan, plan_task: task, scheduled_at: 2.days.from_now)
    profile.update!(professional_context: profile.professional_context.merge("reminders" => [ reminder.id ]))
    stub_backup_generator(task:, source: "professional:organization")
    generated = execute("backups.generate", { event_plan_id: plan.id, scenario: "weather" })
    expect(generated.fetch("records").size).to eq(3)
    option_id = generated.fetch("records").first.fetch("id")
    proposed = execute("backups.promote", { event_plan_id: plan.id, id: option_id })
    action = turn.actions.find(proposed.fetch("action_id"))
    expect(task.reload).not_to be_superseded
    Concierge::Decide.call(user:, action:, decision: "approve", fingerprint: action.fingerprint)
    expect(task.reload).to be_superseded
    expect(plan.plan_tasks.current.pluck(:title)).to eq([ "Prepare indoors 1" ])
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "replaces previously read backup options without treating its own retirement as a source race" do
    task = create(:plan_task, event_plan: plan)
    stub_backup_generator(task:)
    first = execute("backups.generate", { event_plan_id: plan.id, scenario: "weather" })
    second = execute("backups.generate", { event_plan_id: plan.id, scenario: "vendor" })
    expect(second).to include("status" => "succeeded")
    expect(second.fetch("superseded").map { |ref| ref["id"] }).to match_array(first.fetch("records").map { |ref| ref["id"] })
    expect(Concierge::History.sources_current?(turn)).to be(true)
  end

  it "refreshes all read item references after reordering a checklist" do
    result = execute("touches.prepare", { event_plan_id: plan.id })
    checklist = profile.personal_touch_checklists.sole
    first = checklist.personal_touch_items.visible.order(:position).first
    expect(checklist.personal_touch_items.visible.count).to be > 1
    execute("touches.move_down", { checklist_id: checklist.id, id: first.id })
    expect(Concierge::History.sources_current?(turn.reload)).to be(true)
  end

  it "creates the existing checklist and manages an authored touch with the existing lifecycle and audit" do
    result = execute("touches.prepare", { event_plan_id: plan.id })
    checklist = profile.personal_touch_checklists.sole
    expect(result.fetch("records").size).to eq(4)
    expect { execute("touches.prepare", { event_plan_id: plan.id }) }.not_to change(PersonalTouchChecklist, :count)
    result = execute("touches.create", { checklist_id: checklist.id, category: "message", title: "Write a short card" })
    item = checklist.personal_touch_items.find(result.fetch("record").fetch("id"))
    execute("touches.complete", { checklist_id: checklist.id, id: item.id })
    expect(item.reload).to be_completed
    execute("touches.reopen", { checklist_id: checklist.id, id: item.id })
    expect(item.reload).to be_active
    execute("touches.update", { checklist_id: checklist.id, id: item.id, title: "Write the card in Spanish" })
    expect(item.reload.title).to eq("Write the card in Spanish")
    execute("touches.dismiss", { checklist_id: checklist.id, id: item.id })
    expect(item.reload).to be_dismissed
    expect(AuditEvent.where(user:, action: "personal_touch_item.completed")).to exist
  end

  it "rejects foreign checklists and archived occasions before creating records" do
    foreign = create(:personal_touch_checklist)
    expect { execute("touches.create", { checklist_id: foreign.id, category: "message", title: "Private" }) }.to raise_error(ActiveRecord::RecordNotFound)
    plan.archive!
    expect { execute("touches.prepare", { event_plan_id: plan.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    expect(profile.personal_touch_checklists).to be_empty
  end

  it "manages work touches for selected moments and excludes old unselected personal evidence" do
    preference = create(:relationship_preference, relationship_profile: profile, key: "Personal detail", value: "Personal holiday")
    checklist = PersonalTouchChecklists::Create.call(actor: user, moment: plan)
    personal_item = checklist.personal_touch_items.find { |item| item.source_context.any? { |source| source["source_id"] == preference.id } }
    profile.update!(relationship_mode: "professional", professional_context: { "event_plans" => [ plan.id ] })
    result = execute("touches.search", { checklist_id: checklist.id })
    expect(result.fetch("records").pluck("id")).not_to include(personal_item.id)
    expect { execute("touches.complete", { checklist_id: checklist.id, id: personal_item.id }) }.to raise_error(ActiveRecord::RecordNotFound)
    created = execute("touches.create", { checklist_id: checklist.id, category: "message", title: "Review the work agenda" })
    item = checklist.personal_touch_items.find(created.fetch("record").fetch("id"))
    execute("touches.complete", { checklist_id: checklist.id, id: item.id })
    expect(item.reload).to be_completed
    expect { execute("touches.create", { checklist_id: checklist.id, category: "gift", title: "Surprise gift" }) }.to raise_error(Concierge::PermissionDenied)
  end
end
