require "rails_helper"

RSpec.describe EventPlanWorkspaceComponent, type: :component do
  it "renders an accessible, user-controlled plan runway" do
    plan = create(:event_plan)
    create(:plan_task, event_plan: plan, kind: "message_draft", title: "Draft the invitation")

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      vault_unlocked: false
    ))

    expect(page).to have_css("main[aria-labelledby='event-plan-title']")
    expect(page).to have_css("section[aria-labelledby='planning-runway-title']")
    expect(page).to have_button("Suggest next steps")
    expect(page).to have_text("Draft the invitation")
    expect(page).to have_text("Draft only — nothing is sent")
    expect(page).to have_link("Create reminder")
    expect(page).not_to have_button("Send")
  end

  it "does not offer suggestions for a completed plan" do
    plan = create(:event_plan, status: "completed", completed_at: Time.current)

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      vault_unlocked: false
    ))

    expect(page).not_to have_button("Suggest next steps")
  end

  it "identifies each unlocked vault source before per-request selection" do
    plan = create(:event_plan)
    first_item = create(
      :privacy_vault_item,
      relationship_profile: plan.relationship_profile,
      suggestion_usage: "allowed",
      payload: { "title" => "Quiet restaurant preference", "body" => "Choose a calm table." }
    )
    second_item = create(
      :privacy_vault_item,
      relationship_profile: plan.relationship_profile,
      suggestion_usage: "allowed",
      payload: { "title" => "Mobility accommodation", "body" => "Confirm step-free access." }
    )

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [ first_item, second_item ],
      vault_unlocked: true
    ))

    expect(page).to have_field("Quiet restaurant preference", type: "checkbox", with: first_item.id)
    expect(page).to have_field("Mobility accommodation", type: "checkbox", with: second_item.id)
  end

  it "identifies same-day private notes before per-request selection" do
    plan = create(:event_plan)
    first_note = create(
      :relationship_note,
      relationship_profile: plan.relationship_profile,
      private: true,
      body: "Keep the gathering small and quiet."
    )
    second_note = create(
      :relationship_note,
      relationship_profile: plan.relationship_profile,
      private: true,
      body: "Avoid making plans near the hospital."
    )

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [ first_note, second_note ],
      vault_items: [],
      vault_unlocked: false
    ))

    first_label = I18n.t(
      "event_plans.suggestions.private_note_label",
      date: I18n.l(first_note.created_at.to_date, format: :important_date),
      summary: "Keep the gathering small and quiet."
    )
    second_label = I18n.t(
      "event_plans.suggestions.private_note_label",
      date: I18n.l(second_note.created_at.to_date, format: :important_date),
      summary: "Avoid making plans near the hospital."
    )

    expect(page).to have_field(first_label, type: "checkbox", with: first_note.id)
    expect(page).to have_field(second_label, type: "checkbox", with: second_note.id)
  end

  it "renders comparable backup options with an explicit promotion action" do
    plan = create(:event_plan)
    replaced_task = create(
      :plan_task,
      event_plan: plan,
      title: "Confirm the outdoor table",
      details: "The reservation is currently on the terrace."
    )
    reminder = create(
      :reminder,
      user: plan.user,
      relationship_profile: plan.relationship_profile,
      event_plan: plan,
      plan_task: replaced_task,
      title: "Call about the terrace"
    )
    backup_plan = create(
      :backup_plan,
      user: plan.user,
      event_plan: plan,
      event_plan_generation_version: plan.generation_version
    )
    option = create(
      :backup_option,
      backup_plan:,
      title: "Move the dinner indoors",
      replacement_task_ids: [ replaced_task.id ],
      task_blueprints: [
        {
          "phase" => "arrange",
          "kind" => "backup_step",
          "title" => "Confirm the indoor dining room",
          "details" => "Ask the venue to hold the quiet room.",
          "due_on" => "2026-09-10",
          "source_context" => backup_plan.source_context
        }
      ]
    )

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      vault_unlocked: false,
      backup_plan:
    ))

    expect(page).to have_css("section#backup-options[aria-labelledby='backup-options-title']")
    expect(page).to have_select("Choose what changed")
    expect(page).to have_text("Move the dinner indoors")
    expect(page).to have_text("Effort")
    expect(page).to have_text("Timing")
    expect(page).to have_text("Estimated cost")
    expect(page).to have_text("Relationship fit")
    expect(page).to have_text("What stays the same")
    expect(page).to have_text("What will change")
    expect(page).to have_text("Source evidence")
    expect(page).to have_text("Steps this option will add")
    expect(page).to have_text("Confirm the indoor dining room")
    expect(page).to have_text("Ask the venue to hold the quiet room.")
    expect(page).to have_text("Current steps this option will retire")
    expect(page).to have_text("Confirm the outdoor table")
    expect(page).to have_text("The reservation is currently on the terrace.")
    expect(page).to have_text("Active reminders that will be retired")
    expect(page).to have_text("Call about the terrace")
    expect(page).to have_button("Promote this option")
    promote_path = Rails.application.routes.url_helpers.promote_event_plan_backup_plan_path(plan, backup_plan)
    expect(page).to have_css("form[action='#{promote_path}']")
    expect(page).not_to have_button("Book")
    expect(option).not_to be_promoted_at
    expect(reminder).to be_active
  end

  it "does not offer stale backup options for promotion" do
    plan = create(:event_plan, generation_version: 2)
    backup_plan = create(
      :backup_plan,
      user: plan.user,
      event_plan: plan,
      event_plan_generation_version: 1
    )
    create(:backup_option, backup_plan:)

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      vault_unlocked: false,
      backup_plan:
    ))

    expect(page).to have_text("Generate fresh options before promoting one")
    expect(page).not_to have_button("Promote this option")
  end

  it "makes an empty reminder impact explicit before promotion" do
    plan = create(:event_plan)
    replaced_task = create(:plan_task, event_plan: plan, title: "Check the forecast")
    backup_plan = create(
      :backup_plan,
      user: plan.user,
      event_plan: plan,
      event_plan_generation_version: plan.generation_version
    )
    create(
      :backup_option,
      backup_plan:,
      replacement_task_ids: [ replaced_task.id ],
      task_blueprints: [
        {
          "phase" => "decide",
          "kind" => "backup_step",
          "title" => "Choose the weather fallback",
          "details" => nil,
          "due_on" => nil,
          "source_context" => backup_plan.source_context
        }
      ]
    )

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      vault_unlocked: false,
      backup_plan:
    ))

    expect(page).to have_text("Check the forecast")
    expect(page).to have_text("No active reminders are attached to this step.")
  end

  it "identifies the applied option and retains its reviewed impact after promotion" do
    plan = create(:event_plan)
    replaced_task = create(
      :plan_task,
      event_plan: plan,
      title: "Confirm the outdoor table",
      superseded_at: 1.minute.ago
    )
    backup_plan = create(
      :backup_plan,
      user: plan.user,
      event_plan: plan,
      status: "promoted",
      promoted_at: 1.minute.ago
    )
    applied_option = create(
      :backup_option,
      backup_plan:,
      title: "Move indoors",
      promoted_at: 1.minute.ago,
      replacement_task_ids: [ replaced_task.id ],
      reviewed_reminders: [
        {
          "id" => SecureRandom.uuid,
          "plan_task_id" => replaced_task.id,
          "title" => "Call about the terrace",
          "scheduled_at" => "2026-09-01T15:00:00.000000Z",
          "snoozed_until" => nil,
          "time_zone" => "UTC",
          "recurrence" => "none",
          "reminder_type" => "event_preparation",
          "priority" => "normal"
        }
      ]
    )
    create(:backup_option, backup_plan:, title: "Choose another venue")

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      vault_unlocked: false,
      backup_plan:
    ))

    applied = page.find("[data-backup-option-id='#{applied_option.id}']")
    expect(applied).to have_text("Applied to active plan")
    expect(applied).to have_text("Confirm the outdoor table")
    expect(applied).to have_text("Call about the terrace")
    expect(page).to have_css("[data-backup-option-state='promoted']", count: 1)
  end
end
