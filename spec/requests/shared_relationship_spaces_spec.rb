require "rails_helper"

RSpec.describe "Shared couple spaces", type: :request do
  let(:owner) { create(:user) }
  let(:partner) { create(:user) }

  def invite
    sign_in owner
    post shared_relationship_spaces_path, params: { shared_relationship_space: { title: "Our plans", invited_email: partner.email } }
    SharedRelationshipSpace.last
  end

  def accepted_space
    space = invite
    sign_in partner
    post accept_shared_relationship_space_path(space)
    space.reload
  end

  it "requires an explicit invitation and confirmed recipient acceptance before sharing" do
    space = invite
    expect(space.partner_id).to be_nil
    sign_in create(:user)
    post accept_shared_relationship_space_path(space)
    expect(response).to have_http_status(:not_found)
    sign_in partner
    get shared_relationship_spaces_path
    expect(response.body).to include("Our plans", "Accept invitation")
    post shared_relationship_space_shared_items_path(space), params: { shared_item: { title: "Too early", kind: "plan" } }
    expect(response).to have_http_status(:not_found)
    post accept_shared_relationship_space_path(space)
    expect(space.reload.partner).to eq(partner)
    expect(response).to redirect_to(shared_relationship_space_path(space))
  end

  it "rejects expired invitations and allows the creator to cancel" do
    space = invite
    Timecop.travel(8.days.from_now) do
      sign_in partner
      post accept_shared_relationship_space_path(space)
      expect(response).to have_http_status(:not_found)
    end
    sign_in owner
    delete shared_relationship_space_path(space), params: { confirm_end: "1" }
    expect(SharedRelationshipSpace.exists?(space.id)).to be(false)
  end

  it "coordinates shared plans, tasks and reminders without exposing private notes" do
    space = accepted_space
    profile = create(:relationship_profile, user: owner)
    create(:relationship_note, relationship_profile: profile, body: "Private surprise", private: true)
    post shared_relationship_space_shared_items_path(space), params: { shared_item: { title: "Dinner", kind: "plan", editing: "participants" } }
    plan = space.shared_items.sole
    sign_in owner
    post shared_relationship_space_shared_items_path(space), params: { shared_item: { title: "Choose restaurant", kind: "task", parent_id: plan.id, editing: "participants" } }
    task = space.shared_items.find_by!(kind: "task")
    sign_in partner
    post claim_shared_relationship_space_shared_item_path(space, task), params: { lock_version: task.reload.lock_version }
    expect(task.reload.assignee).to eq(partner)
    patch shared_relationship_space_shared_item_path(space, task), params: { shared_item: { title: "Choose quiet restaurant", lock_version: task.lock_version } }
    expect(task.reload.title).to eq("Choose quiet restaurant")
    post complete_shared_relationship_space_shared_item_path(space, task), params: { lock_version: task.lock_version }
    expect(task.reload.completed_at).to be_present
    get shared_relationship_space_path(space)
    expect(response.body).to include("Dinner", "Choose quiet restaurant", "Your private notes stay private")
    expect(response.body).not_to include("Private surprise")
    get relationship_profile_path(profile)
    expect(response).to have_http_status(:not_found)
  end

  it "keeps ownership and editing rules explicit and rejects stale changes" do
    space = accepted_space
    sign_in owner
    post shared_relationship_space_shared_items_path(space), params: { shared_item: { title: "Shared note", kind: "note", editing: "creator" } }
    item = space.shared_items.sole
    sign_in partner
    patch shared_relationship_space_shared_item_path(space, item), params: { shared_item: { title: "Overwrite", editing: "participants", creator_id: partner.id, lock_version: 0 } }
    expect(response).to have_http_status(:forbidden)
    delete shared_relationship_space_shared_item_path(space, item)
    expect(response).to have_http_status(:forbidden)
    sign_in owner
    patch shared_relationship_space_shared_item_path(space, item), params: { shared_item: { title: "New revision", lock_version: 0 } }
    patch shared_relationship_space_shared_item_path(space, item), params: { shared_item: { title: "Stale revision", lock_version: 0 } }
    expect(response).to have_http_status(:conflict)
    expect(item.reload.title).to eq("New revision")
  end

  it "allows either participant to end sharing only after explicit confirmation" do
    space = accepted_space
    delete shared_relationship_space_path(space)
    expect(response).to have_http_status(:unprocessable_content)
    delete shared_relationship_space_path(space), params: { confirm_end: "1" }
    sign_in owner
    get shared_relationship_space_path(space)
    expect(response).to have_http_status(:not_found)
  end

  it "renders invitation and sharing controls in Spanish" do
    space = accepted_space
    I18n.with_locale(:es) { get shared_relationship_space_path(space) }
    expect(response.body).to include("Agregar contenido compartido", "Terminar el espacio compartido")
    expect(response.body).not_to include("Translation missing")
  end
  it "keeps foreign plans and items outside the shared workspace, including failed forms" do
    space = accepted_space
    foreign = create(:shared_item, title: "Foreign private planning")
    post shared_relationship_space_shared_items_path(space), params: { shared_item: { title: "Task", kind: "task", parent_id: foreign.id } }
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include(foreign.title)
    get edit_shared_relationship_space_shared_item_path(space, foreign)
    expect(response).to have_http_status(:not_found)
    sign_in create(:user)
    get shared_relationship_space_path(space)
    expect(response).to have_http_status(:not_found)
  end

  it "requires the recipient to accept, prevents stealing task responsibility, and keeps kinds stable" do
    space = invite
    post accept_shared_relationship_space_path(space)
    expect(response).to have_http_status(:not_found)
    sign_in partner
    post accept_shared_relationship_space_path(space)
    task = create(:shared_item, shared_relationship_space: space.reload, kind: "task", creator: owner)
    post claim_shared_relationship_space_shared_item_path(space, task), params: { lock_version: task.reload.lock_version }
    sign_in owner
    post claim_shared_relationship_space_shared_item_path(space, task), params: { lock_version: task.reload.lock_version }
    expect(response).to have_http_status(:forbidden)
    patch shared_relationship_space_shared_item_path(space, task), params: { shared_item: { kind: "note", editing: "creator", lock_version: task.reload.lock_version } }
    expect(task.reload.kind).to eq("task")
    expect(task.editing).to eq("creator")
    sign_in partner
    post claim_shared_relationship_space_shared_item_path(space, task), params: { lock_version: task.reload.lock_version }
    expect(task.reload.assignee).to be_nil
  end

  it "offers valid English and Spanish item forms and keeps reminder subscriptions personal" do
    space = accepted_space
    get new_shared_relationship_space_shared_item_path(space)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Only the creator", "turbo-cache-control")
    post shared_relationship_space_shared_items_path(space), params: { shared_item: { title: "Remember dinner", kind: "reminder", time_zone: "America/Costa_Rica", scheduled_local: "2027-01-20T18:00" } }
    item = space.shared_items.sole
    expect(item.due_at).to eq(Time.utc(2027, 1, 21))
    post subscribe_shared_relationship_space_shared_item_path(space, item), params: { user_id: owner.id }
    expect(item.shared_reminder_subscriptions.pluck(:user_id)).to eq([ partner.id ])
    post subscribe_shared_relationship_space_shared_item_path(space, item)
    expect(item.shared_reminder_subscriptions.count).to eq(1)
    I18n.with_locale(:es) { get edit_shared_relationship_space_shared_item_path(space, item) }
    expect(response.body).to include("Detalles compartidos", "Zona horaria")
    expect(response.body).not_to include("Translation missing")
    delete unsubscribe_shared_relationship_space_shared_item_path(space, item)
    expect(item.shared_reminder_subscriptions.sole).not_to be_enabled
    get shared_relationship_space_path(space)
    expect(response.body).to include(I18n.t("shared_spaces.subscribe"))
    exported = DataExports::Snapshot.new(user: partner).to_h.fetch("shared_relationship_spaces").sole
    expect(exported.fetch("items").sole.fetch("my_reminder_enabled")).to be(false)
    delete shared_relationship_space_shared_item_path(space, item)
    expect(SharedItem.exists?(item.id)).to be(false)
  end

  it "renders invalid input without sharing it and rejects missing revisions" do
    space = accepted_space
    post shared_relationship_space_shared_items_path(space), params: { shared_item: { title: "", kind: "reminder", time_zone: "Unknown", scheduled_local: "not a date" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(space.shared_items.count).to eq(0)
    item = create(:shared_item, shared_relationship_space: space)
    patch shared_relationship_space_shared_item_path(space, item), params: { shared_item: { title: "Missing revision" } }
    expect(response).to have_http_status(:conflict)
    post complete_shared_relationship_space_shared_item_path(space, item), params: { lock_version: item.lock_version }
    post complete_shared_relationship_space_shared_item_path(space, item), params: { lock_version: item.reload.lock_version }
    expect(item.reload.completed_at).to be_nil
  end

  it "exports only participating active spaces and the requesting person's subscription preference" do
    space = accepted_space
    item = create(:shared_item, shared_relationship_space: space, kind: "reminder", due_at: 1.day.from_now)
    item.shared_reminder_subscriptions.create!(user: owner)
    create(:shared_relationship_space, title: "Foreign space")
    result = DataExports::Snapshot.new(user: partner).to_h.fetch("shared_relationship_spaces")
    expect(result.pluck("id")).to eq([ space.id ])
    expect(result.first.fetch("items").first).to include("title" => item.title, "my_reminder_enabled" => false)
    expect(result.to_json).not_to include("delivered_for", "Foreign space")
    expect(DataExports::Snapshot.new(user: create(:user)).to_h.fetch("shared_relationship_spaces")).to be_empty
  end
  it "shows delivered shared alerts only in the subscribed participant's reminder inbox" do
    space = accepted_space
    item = create(:shared_item, shared_relationship_space: space, kind: "reminder", due_at: 1.minute.ago)
    item.shared_reminder_subscriptions.create!(user: partner)
    DispatchSharedRemindersJob.perform_now
    get reminders_path
    expect(response.body).to include("A reminder in your shared space is due.", shared_relationship_space_path(space))
    sign_in owner
    get reminders_path
    expect(response.body).not_to include("A reminder in your shared space is due.")
  end

  it "rejects a repeated stale claim instead of releasing an accepted responsibility" do
    space = accepted_space
    task = create(:shared_item, shared_relationship_space: space, kind: "task")
    2.times { post claim_shared_relationship_space_shared_item_path(space, task), params: { lock_version: 0 } }
    expect(response).to have_http_status(:conflict)
    expect(task.reload.assignee).to eq(partner)
  end
  it "localizes validation labels in the Spanish invitation and item forms" do
    sign_in owner
    I18n.with_locale(:es) do
      post shared_relationship_spaces_path, params: { shared_relationship_space: { title: "", invited_email: "" } }
    end
    expect(response).to have_http_status(:unprocessable_content)
    expect(Nokogiri::HTML5(response.body).at_css("[role=alert]").text).to include("Nombre", "Correo")
    space = accepted_space
    I18n.with_locale(:es) do
      post shared_relationship_space_shared_items_path(space), params: { shared_item: { title: "", kind: "reminder" } }
    end
    expect(Nokogiri::HTML5(response.body).at_css("[role=alert]").text).to include("Título", "Fecha")
  end
  it "exports participating spaces in stable creation order" do
    space = accepted_space
    earlier = create(:shared_relationship_space, owner:, partner:, invited_email: partner.email, created_at: space.created_at - 1.day)
    result = DataExports::Snapshot.new(user: partner).to_h.fetch("shared_relationship_spaces")
    expect(result.pluck("id")).to eq([ earlier.id, space.id ])
  end
end
