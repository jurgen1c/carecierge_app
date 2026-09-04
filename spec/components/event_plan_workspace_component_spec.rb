require "rails_helper"

RSpec.describe EventPlanWorkspaceComponent, type: :component do
  include ActiveSupport::Testing::TimeHelpers

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

  it "routes a booking-owned task back to its booking instead of generic task mutations" do
    booking = create(:booking)
    Bookings::Save.call(booking, attributes: {}, locale: :en)

    render_inline(described_class.new(
      event_plan: booking.event_plan,
      event_plans: [ booking.event_plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      bookings: [ booking ]
    ))

    task_row = page.find("#plan-task-#{booking.plan_task_id}")
    expect(task_row).to have_text("Managed from the booking status")
    expect(task_row).to have_link("Manage booking", href: Rails.application.routes.url_helpers.edit_booking_path(booking))
    expect(task_row).to have_no_button("Mark complete")
    expect(task_row).to have_no_button("Remove task")
    expect(task_row).to have_no_text("Edit details")
    expect(task_row).to have_css(".booking-task-state.border-stone-300.bg-canvas.text-quiet-note")
  end

  it "shows attached vendors and a direct, review-only discovery path" do
    plan = create(:event_plan)
    vendor = create(:vendor, user: plan.user, name: "Casa Verde", category: "restaurant")
    create(:event_plan_vendor, event_plan: plan, vendor:)

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      vendors: [ vendor ]
    ))

    expected_path = Rails.application.routes.url_helpers.vendors_path(event_plan_id: plan.id)
    expect(page).to have_link("Find vendors", href: expected_path, count: 2)
    expect(page).to have_css("section[aria-labelledby='saved-vendors-title']")
    expect(page).to have_link("Compare quotes", href: Rails.application.routes.url_helpers.event_plan_vendor_quotes_path(plan))
    expect(page).to have_content("Casa Verde")
    expect(page).to have_content("Restaurant")
    expect(page).to have_no_button("Book")
  end

  it "gives a birthday plan one clear, review-only next action" do
    plan = create(:event_plan, occasion_type: "birthday", starts_on: Date.current + 21.days)
    next_task = create(
      :plan_task,
      event_plan: plan,
      kind: "gift_idea",
      title: "Choose a birthday gift",
      due_on: Date.current + 2.days
    )
    create(:plan_task, event_plan: plan, kind: "message_draft", due_on: Date.current + 3.days, position: 1)

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      vault_unlocked: false
    ))

    expect(page).to have_css("section[aria-labelledby='birthday-next-action-title']")
    expect(page).to have_text("Your next step")
    expect(page).to have_text(next_task.title)
    expect(page).to have_link(
      "Review gift ideas",
      href: Rails.application.routes.url_helpers.relationship_profile_path(
        plan.relationship_profile,
        anchor: "gift-recommendations"
      )
    )
    expect(page).to have_text("You review every draft and decide what happens next")
    expect(page).to have_text("Warm tone")
    expect(page).not_to have_text("Medium effort")
    expect(page).not_to have_button("Buy")
  end


  it "gives an anniversary plan one respectful, review-only next action and visible planning preferences" do
    plan = create(
      :event_plan,
      occasion_type: "anniversary",
      tone: "understated",
      effort_level: "low",
      starts_on: Date.current + 21.days
    )
    next_task = create(:plan_task, event_plan: plan, kind: "message_draft", title: "Draft a simple note")

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      vault_unlocked: false
    ))

    expect(page).to have_css("section[aria-labelledby='anniversary-next-action-title']")
    expect(page).to have_text("Anniversary concierge")
    expect(page).to have_text(next_task.title)
    expect(page).to have_text("Understated tone")
    expect(page).to have_text("Low effort")
    expect(page).to have_link("Draft a message")
    expect(page).to have_text("Nothing is sent, booked, purchased, or shared automatically")
    expect(page).not_to have_button("Book")
  end

  it "routes birthday next actions into existing user-controlled workflows" do
    routes = Rails.application.routes.url_helpers
    {
      "message_draft" => [ "Draft a message", ->(plan, _task) { routes.relationship_profile_path(plan.relationship_profile, anchor: "message-drafting") } ],
      "reminder" => [ "Set a reminder", ->(plan, task) { routes.new_reminder_path(relationship_profile_id: plan.relationship_profile_id, event_plan_id: plan.id, plan_task_id: task.id) } ],
      "backup_step" => [ "Review backup options", ->(plan, _task) { routes.event_plan_path(plan, anchor: "backup-options") } ],
      "decision" => [ "Open this step", ->(plan, task) { routes.event_plan_path(plan, anchor: "plan-task-#{task.id}") } ]
    }.each do |kind, (label, path_for)|
      plan = create(:event_plan, occasion_type: "birthday")
      task = create(:plan_task, event_plan: plan, kind:)

      render_inline(described_class.new(
        event_plan: plan,
        event_plans: [ plan ],
        plan_task: PlanTask.new,
        private_notes: [],
        vault_items: [],
        vault_unlocked: false
      ))

      expect(page).to have_link(label, href: path_for.call(plan, task))
    end
  end

  it "does not offer a next action for a completed birthday plan" do
    plan = create(:event_plan, occasion_type: "birthday", status: "completed", completed_at: Time.current)
    create(:plan_task, event_plan: plan, kind: "reminder")

    render_inline(described_class.new(
      event_plan: plan,
      event_plans: [ plan ],
      plan_task: PlanTask.new,
      private_notes: [],
      vault_items: [],
      vault_unlocked: false
    ))

    expect(page).not_to have_css("section[aria-labelledby='birthday-next-action-title']")
    expect(page).to have_no_link("Find vendors")
  end

  it "describes birthday timing from the owner's local calendar date" do
    plan = create(:event_plan, occasion_type: "birthday", starts_on: Date.new(2026, 8, 22))
    create(:notification_preference, user: plan.user, time_zone: "America/Los_Angeles")
    create(:plan_task, event_plan: plan)

    travel_to Time.utc(2026, 8, 23, 2) do
      render_inline(described_class.new(
        event_plan: plan,
        event_plans: [ plan ],
        plan_task: PlanTask.new,
        private_notes: [],
        vault_items: [],
        vault_unlocked: false
      ))
    end

    expect(page).to have_text("Birthday is today")
    expect(page).not_to have_text("Birthday date has passed")
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
