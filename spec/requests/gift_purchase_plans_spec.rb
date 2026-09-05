require "rails_helper"

RSpec.describe "Gift purchase planning", type: :request do
  let(:gift) { create(:gift, name: "A thoughtful book") }
  let(:profile) { gift.relationship_profile }
  let(:path) { relationship_profile_gift_purchase_plan_path(profile, gift) }
  let(:attributes) do
    { budget: "30.25", currency: "USD", purchase_by: "2026-10-01", expected_delivery_on: "2026-10-04",
      shipping_notes: "Private delivery instructions", constraints: "No leather", follow_up_notes: "Wrap and add a card",
      follow_up_on: "2026-10-05", purchase_status: "purchased", delivery_status: "awaiting",
      options: { "0" => { vendor: "Local books", url: "https://books.example/gift", cost: "24.95", constraints_checked: "1" } } }
  end

  before { sign_in profile.user }

  it "saves one private plan, renders safe options, and requires a current revision" do
    expect { put path, params: { gift_purchase_plan: attributes.merge(lock_version: "new") } }.to change(GiftPurchasePlan, :count).by(1)
    expect(response).to redirect_to(path)
    plan = gift.reload.purchase_plan
    expect(plan).to have_attributes(budget: BigDecimal("30.25"), purchase_status: "purchased", shipping_notes: "Private delivery instructions")
    get path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Suggested option", "Local books", "Manual tracking only")
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.parsed_body.at_css("a[href='https://books.example/gift']")["rel"]).to include("noreferrer")
    plan.update!(shipping_notes: "Newer note")
    put path, params: { gift_purchase_plan: attributes.merge(lock_version: "0") }
    expect(response).to redirect_to(path)
    expect(flash[:alert]).to be_present
    expect(plan.reload.shipping_notes).to eq("Newer note")
    put path, params: { gift_purchase_plan: attributes }
    expect(response).to have_http_status(:bad_request)
  end

  it "renders invalid data and Spanish labels without losing entered notes" do
    put path, params: { gift_purchase_plan: attributes.merge(budget: "bad", lock_version: "new") }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Private delivery instructions")
    expect(GiftPurchasePlan.count).to eq(0)
    I18n.with_locale(:es) { get path }
    expect(response.body).to include("Preparar la compra", "Presupuesto")
    expect(response.body).not_to include("Translation missing")
  end

  it "carries the saved gift vendor and estimate into an unconfirmed draft option" do
    gift.update!(vendor: "Suggested local shop", price_cents: 2495)
    get path
    expect(response.parsed_body.at_css("input[name='gift_purchase_plan[options][0][vendor]']")["value"]).to eq("Suggested local shop")
    expect(response.parsed_body.at_css("input[name='gift_purchase_plan[options][0][cost]']")["value"]).to eq("24.95")
    expect(GiftPurchasePlan.count).to eq(0)
  end

  it "denies another owner and archived profiles" do
    other = create(:gift)
    get relationship_profile_gift_purchase_plan_path(other.relationship_profile, other)
    expect(response).to have_http_status(:not_found)
    profile.discard!
    put path, params: { gift_purchase_plan: attributes.merge(lock_version: "new") }
    expect(response).to have_http_status(:not_found)
  end

  it "adds one reviewed task to the selected active plan of this relationship" do
    put path, params: { gift_purchase_plan: attributes.merge(lock_version: "new") }
    event = create(:event_plan, user: profile.user, relationship_profile: profile)
    task_path = task_relationship_profile_gift_purchase_plan_path(profile, gift)
    expect { post task_path, params: { event_plan_id: event.id } }.to change(PlanTask, :count).by(1)
    task = gift.reload.purchase_plan.plan_task
    expect(task).to have_attributes(event_plan: event, kind: "gift_idea", due_on: Date.new(2026, 10, 1))
    expect { post task_path, params: { event_plan_id: event.id } }.not_to change(PlanTask, :count)
    foreign = create(:event_plan)
    post task_path, params: { event_plan_id: foreign.id }
    expect(response).to have_http_status(:not_found)
  end

  it "rejects inactive or mismatched plans and permits reattachment after explicit task removal" do
    put path, params: { gift_purchase_plan: attributes.merge(lock_version: "new") }
    event = create(:event_plan, user: profile.user, relationship_profile: profile)
    task_path = task_relationship_profile_gift_purchase_plan_path(profile, gift)
    mismatch = create(:event_plan, user: profile.user, relationship_profile: create(:relationship_profile, user: profile.user))
    post task_path, params: { event_plan_id: mismatch.id }
    expect(response).to have_http_status(:not_found)
    event.update!(status: "completed")
    expect { post task_path, params: { event_plan_id: event.id } }.not_to change(PlanTask, :count)
    expect(response).to have_http_status(:not_found)
    event.update!(status: "active")
    post task_path, params: { event_plan_id: event.id }
    original = gift.reload.purchase_plan.plan_task
    original.destroy!
    expect(gift.purchase_plan.reload.plan_task_id).to be_nil
    expect { post task_path, params: { event_plan_id: event.id } }.to change(PlanTask, :count).by(1)
  end

  it "offers an explicit replacement for a superseded purchase task", :aggregate_failures do
    put path, params: { gift_purchase_plan: attributes.merge(lock_version: "new") }
    event = create(:event_plan, user: profile.user, relationship_profile: profile)
    task_path = task_relationship_profile_gift_purchase_plan_path(profile, gift)
    post task_path, params: { event_plan_id: event.id }
    original = gift.reload.purchase_plan.plan_task
    original.update!(completed_at: Time.zone.local(2026, 9, 5))
    expect { post task_path, params: { event_plan_id: event.id } }.not_to change(PlanTask, :count)

    original.update!(completed_at: nil, superseded_at: Time.zone.local(2026, 9, 5))
    expect { get path }.not_to change(PlanTask, :count)
    expect(response.parsed_body.at_css("form[action='#{task_path}']")).to be_present
    expect { post task_path, params: { event_plan_id: event.id } }.to change(PlanTask, :count).by(1)
    replacement = gift.purchase_plan.reload.plan_task
    expect(replacement.id).not_to eq(original.id)
    expect(replacement).not_to be_superseded
    expect(original.reload).to be_superseded
    expect { post task_path, params: { event_plan_id: event.id } }.not_to change(PlanTask, :count)
  end

  it "captures the browser zone without reloading an undated milestone" do
    put path, params: { gift_purchase_plan: attributes.merge(follow_up_on: "", lock_version: "new") }
    plan = gift.reload.purchase_plan
    get new_reminder_path(gift_purchase_plan_id: plan.id, gift_milestone: "follow_up")
    form = response.parsed_body.at_css("form[data-controller='timezone']")
    expect(form["data-timezone-capture-value"]).to eq("true")
    expect(form["data-timezone-reload-value"]).to eq("false")
    get new_reminder_path(gift_purchase_plan_id: plan.id, gift_milestone: "purchase")
    expect(response.parsed_body.at_css("form[data-controller='timezone']")["data-timezone-reload-value"]).to eq("true")
  end

  it "prefills a private reminder for review without scheduling it" do
    put path, params: { gift_purchase_plan: attributes.merge(lock_version: "new") }
    plan = gift.reload.purchase_plan
    create(:notification_preference, user: profile.user, time_zone: "America/Costa_Rica", time_zone_configured: true)
    expect { get new_reminder_path(gift_purchase_plan_id: plan.id, gift_milestone: "follow_up") }.not_to change(Reminder, :count)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.at_css("input[name='reminder[title]']")["value"]).to include("A thoughtful book")
    expect(response.parsed_body.at_css("input[name='reminder[scheduled_at]']")["value"]).to eq("2026-10-05T09:00")
    expect(response.body).not_to include("Private delivery instructions")
    sign_in create(:user)
    get new_reminder_path(gift_purchase_plan_id: plan.id)
    expect(response).to have_http_status(:not_found)
  end
end
