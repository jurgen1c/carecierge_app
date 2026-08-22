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
end
