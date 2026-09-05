require "rails_helper"

RSpec.describe "Family coordination", type: :request do
  let(:owner) { create(:user) }
  let(:sibling) { create(:user) }
  let(:parent) { create(:user) }

  def family
    @family ||= begin
      sign_in owner
      post shared_relationship_spaces_path, params: { shared_relationship_space: { title: "Our family", mode: "family" } }
      SharedRelationshipSpace.last
    end
  end

  def join(person, type: "sibling")
    space = family
    sign_in owner
    post shared_relationship_space_family_memberships_path(space), params: { family_membership: { invited_email: person.email, relationship_type: type } }
    membership = space.family_memberships.find_by!(invited_email: person.email)
    sign_in person
    post accept_family_membership_path(membership)
    membership.reload
  end

  it "creates a family and admits multiple explicitly consenting relatives" do
    expect(family).to be_family
    expect(family).to be_active
    membership = join(sibling)
    expect(membership.user).to eq(sibling)
    join(parent, type: "parent")
    get shared_relationship_space_path(family)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Our family", "Sibling", "Parent", "Family calendar")
    expect(family.reload).to be_participant(parent)
    expect(family).to be_participant(sibling)
  end

  it "does not reveal family content to pending invitees or foreign users" do
    space = family
    post shared_relationship_space_family_memberships_path(space), params: { family_membership: { invited_email: sibling.email, relationship_type: "sibling" } }
    membership = space.family_memberships.sole
    sign_in sibling
    get shared_relationship_space_path(space)
    expect(response).to have_http_status(:not_found)
    get shared_relationship_spaces_path
    expect(response.body).to include("Our family", "Accept invitation")
    sign_in parent
    post accept_family_membership_path(membership)
    expect(response).to have_http_status(:not_found)
    Timecop.travel(8.days.from_now) do
      sign_in sibling
      post accept_family_membership_path(membership)
      expect(response).to have_http_status(:not_found)
    end
  end

  it "coordinates birthdays, care, gifts, holiday plans and self RSVP without importing personal notes" do
    join(sibling)
    profile = create(:relationship_profile, user: owner)
    create(:relationship_note, relationship_profile: profile, body: "Private family boundary", private: true)
    post shared_relationship_space_shared_items_path(family), params: { shared_item: { title: "Holiday lunch", kind: "plan", category: "rsvp", editing: "participants" } }
    plan = family.shared_items.sole
    post respond_shared_relationship_space_shared_item_path(family, plan), params: { attendance: "yes", user_id: owner.id }
    expect(plan.family_responses.sole.user).to eq(sibling)
    post shared_relationship_space_shared_items_path(family), params: { shared_item: { title: "Bring groceries", kind: "task", category: "care", parent_id: plan.id } }
    task = family.shared_items.find_by!(kind: "task")
    post claim_shared_relationship_space_shared_item_path(family, task), params: { lock_version: task.lock_version }
    expect(task.reload.assignee).to eq(sibling)
    get shared_relationship_space_path(family), params: { view: "mine" }
    expect(response.body).to include("Bring groceries")
    expect(response.body).not_to include("Private family boundary")
    get shared_relationship_space_path(family), params: { view: "calendar" }
    expect(response.body).not_to include("Bring groceries")
  end

  it "lets a member leave and removes their contributions, reminders, responses and assigned responsibility" do
    membership = join(sibling)
    task = create(:shared_item, shared_relationship_space: family, creator: owner, kind: "task", assignee: sibling)
    note = create(:shared_item, shared_relationship_space: family, creator: sibling, kind: "note")
    reminder = create(:shared_item, shared_relationship_space: family, creator: owner, kind: "reminder", due_at: 1.minute.ago)
    reminder.shared_reminder_subscriptions.create!(user: sibling)
    DispatchSharedRemindersJob.perform_now
    delete family_membership_path(membership), params: { confirm_leave: "1" }
    expect(response).to have_http_status(:redirect)
    expect(SharedItem.exists?(note.id)).to be(false)
    expect(task.reload.assignee).to be_nil
    expect(reminder.shared_reminder_subscriptions.reload).to be_empty
    expect(sibling.notifications).to be_empty
    get shared_relationship_space_path(family)
    expect(response).to have_http_status(:not_found)
    expect(DataExports::Snapshot.new(user: sibling).to_h.fetch("shared_relationship_spaces")).to be_empty
  end

  it "keeps invitation management with the owner and requires destructive confirmation" do
    member = join(sibling)
    post shared_relationship_space_family_memberships_path(family), params: { family_membership: { invited_email: parent.email, relationship_type: "parent" } }
    expect(response).to have_http_status(:forbidden)
    delete shared_relationship_space_path(family), params: { confirm_end: "1" }
    expect(response).to have_http_status(:forbidden)
    delete family_membership_path(member)
    expect(response).to have_http_status(:unprocessable_content)
    expect(member.reload.user).to eq(sibling)
  end
  it "renders family forms and validation in both supported locales" do
    join(sibling)
    I18n.with_locale(:es) do
      get shared_relationship_space_path(family)
      expect(response.body).to include("Calendario familiar", "Hermana o hermano")
      expect(response.body).not_to include("Translation missing")
      get new_shared_relationship_space_shared_item_path(family), params: { kind: "plan", category: "rsvp" }
      expect(response.body).to include("Actividad familiar", "Todos los familiares pueden editar")
      post shared_relationship_space_shared_items_path(family), params: { shared_item: { title: "", kind: "plan" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).not_to include("Translation missing")
    end
  end

  it "validates personal RSVP and exports accepted membership without pending invitation addresses" do
    join(sibling)
    plan = create(:shared_item, shared_relationship_space: family, creator: owner, category: "rsvp")
    post respond_shared_relationship_space_shared_item_path(family, plan), params: { attendance: "yes" }
    post respond_shared_relationship_space_shared_item_path(family, plan), params: { attendance: "maybe" }
    expect(plan.family_responses.sole.attendance).to eq("maybe")
    post respond_shared_relationship_space_shared_item_path(family, plan), params: { attendance: "invalid" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(plan.family_responses.sole.attendance).to eq("maybe")
    sign_in owner
    post shared_relationship_space_family_memberships_path(family), params: { family_membership: { invited_email: "pending@example.test", relationship_type: "other" } }
    sign_in sibling
    exported = DataExports::Snapshot.new(user: sibling).to_h.fetch("shared_relationship_spaces").sole
    expect(exported.fetch("family_members").sole.fetch("user_id")).to eq(sibling.id)
    expect(exported.to_json).not_to include("pending@example.test")
    expect(exported.fetch("items").sole.fetch("rsvp_responses").sole).to include("attendance" => "maybe")
    get shared_relationship_space_path(family)
    expect(response.body).not_to include("pending@example.test")
  end

  it "keeps all family categories and dated reminders usable without requiring participation" do
    join(sibling)
    SharedItem::CATEGORIES.each do |category|
      post shared_relationship_space_shared_items_path(family), params: { shared_item: { title: "Coordinate #{category}", kind: "reminder", category: category, time_zone: "America/Costa_Rica", scheduled_local: "2027-12-24T12:00" } }
      expect(response).to have_http_status(:redirect)
    end
    reminder = family.shared_items.find_by!(category: "birthday")
    expect(reminder.shared_reminder_subscriptions).to be_empty
    post subscribe_shared_relationship_space_shared_item_path(family, reminder), params: { user_id: owner.id }
    Timecop.travel(Time.utc(2027, 12, 25)) do
      2.times { DispatchSharedRemindersJob.perform_now }
    end
    expect(sibling.notifications.count).to eq(1)
    expect(owner.notifications.count).to eq(0)
    get shared_relationship_space_path(family), params: { category: "birthday", view: "calendar" }
    expect(response.body).to include("Coordinate birthday")
    expect(response.body).not_to include("Coordinate care")
  end
  it "allows the organizer to revoke membership and requires a fresh invitation to rejoin" do
    membership = join(sibling)
    sign_in owner
    delete family_membership_path(membership), params: { confirm_leave: "1" }
    expect(response).to have_http_status(:redirect)
    sign_in sibling
    post accept_family_membership_path(membership)
    expect(response).to have_http_status(:not_found)
    post shared_relationship_space_shared_items_path(family), params: { shared_item: { title: "No longer shared", kind: "note" } }
    expect(response).to have_http_status(:not_found)
  end
  it "keeps family creation independent of pending couple invitation capacity" do
    create_list(:shared_relationship_space, 5, owner: owner, partner: nil, accepted_at: nil, invited_email: sibling.email)
    expect(family).to be_family
  end
end
