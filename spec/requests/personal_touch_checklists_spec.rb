require "rails_helper"

RSpec.describe "Personal touch checklists", type: :request do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:) }

  before { sign_in user }

  it "attaches a checklist to an owned event plan" do
    plan = create(:event_plan, user:, relationship_profile: profile)

    expect do
      post event_plan_personal_touch_checklist_path(plan)
    end.to change(PersonalTouchChecklist, :count).by(1)

    expect(response).to redirect_to(event_plan_path(plan, anchor: "personal-touch-checklist"))
    expect(plan.reload.personal_touch_checklist.personal_touch_items).not_to be_empty
  end

  it "attaches a checklist to birthdays, anniversaries, and other important dates" do
    dates = %w[birthday anniversary custom].map do |date_type|
      create(:important_date, relationship_profile: profile, date_type:, title: "#{date_type.titleize} moment")
    end

    dates.each do |important_date|
      post relationship_profile_important_date_personal_touch_checklist_path(profile, important_date)

      expect(response).to redirect_to(relationship_profile_path(profile, anchor: "personal-touch-#{important_date.id}"))
      expect(important_date.reload.personal_touch_checklist).to be_present
    end
  end

  it "does not expose another user's event plan or date" do
    foreign_plan = create(:event_plan)
    foreign_date = create(:important_date)

    post event_plan_personal_touch_checklist_path(foreign_plan)
    expect(response).to have_http_status(:not_found)

    post relationship_profile_important_date_personal_touch_checklist_path(
      foreign_date.relationship_profile,
      foreign_date
    )
    expect(response).to have_http_status(:not_found)
  end

  it "lets the owner add, complete, reorder, reopen, and dismiss items" do
    checklist = create(:personal_touch_checklist, relationship_profile: profile, event_plan: create(:event_plan, user:, relationship_profile: profile))
    first = create(:personal_touch_item, personal_touch_checklist: checklist, position: 0, title: "First")
    second = create(:personal_touch_item, personal_touch_checklist: checklist, position: 1, title: "Second")

    expect do
      post personal_touch_checklist_personal_touch_items_path(checklist), params: {
        personal_touch_item: {
          category: "accessibility_need",
          title: "Confirm step-free access",
          details: "Call the venue before booking"
        }
      }
    end.to change(checklist.personal_touch_items, :count).by(1)

    created = checklist.personal_touch_items.reload.find { |item| item.title == "Confirm step-free access" }
    expect(created).to have_attributes(origin: "manual", category: "accessibility_need", source_context: [])

    patch complete_personal_touch_checklist_personal_touch_item_path(checklist, first)
    expect(first.reload).to be_completed

    patch reopen_personal_touch_checklist_personal_touch_item_path(checklist, first)
    expect(first.reload).to be_active

    patch move_up_personal_touch_checklist_personal_touch_item_path(checklist, second)
    expect(checklist.personal_touch_items.visible.ordered.first).to eq(second.reload)

    patch dismiss_personal_touch_checklist_personal_touch_item_path(checklist, created)
    expect(created.reload).to be_dismissed

    expect(AuditEvent.where(user:, target: profile).pluck(:action)).to include(
      "personal_touch_item.created",
      "personal_touch_item.completed",
      "personal_touch_item.reopened",
      "personal_touch_item.reordered",
      "personal_touch_item.dismissed"
    )
  end

  it "rejects another user's item mutation" do
    foreign_item = create(:personal_touch_item)

    patch complete_personal_touch_checklist_personal_touch_item_path(
      foreign_item.personal_touch_checklist,
      foreign_item
    )

    expect(response).to have_http_status(:not_found)
    expect(foreign_item.reload).to be_active
  end

  it "renders attached checklists in both supported locales" do
    plan = create(:event_plan, user:, relationship_profile: profile)
    create(:personal_touch_checklist, relationship_profile: profile, event_plan: plan)

    get event_plan_path(plan)
    expect(response.body).to include("Personal touches")

    I18n.with_locale(:es) { get event_plan_path(plan) }
    expect(response.body).to include("Detalles personales")
  end
end
