require "rails_helper"

RSpec.describe FamilyMembership do
  let(:space) { create(:shared_relationship_space, mode: "family", partner: nil, invited_email: nil, accepted_at: nil) }
  let(:person) { create(:user) }

  def invite
    space.family_memberships.create!(invited_email: person.email, relationship_type: "chosen_family", invitation_expires_at: 7.days.from_now)
  end

  it "encrypts invitation addresses and rejects invalid family relationships" do
    membership = invite
    expect(membership.invited_email_before_type_cast).not_to include(person.email)
    expect(membership.update(relationship_type: "guardian_with_authority")).to be(false)
    expect(space.family_memberships.build(invited_email: space.owner.email, relationship_type: "parent", invitation_expires_at: 7.days.from_now)).not_to be_valid
  end

  it "refuses unconfirmed recipients and duplicate acceptance" do
    membership = invite
    person.update!(confirmed_at: nil)
    expect { membership.accept!(person) }.to raise_error(ActiveRecord::RecordNotFound)
    person.confirm
    membership.accept!(person)
    expect { membership.accept!(person) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "cleans departing account contributions while preserving the family and others' plans" do
    invite.accept!(person)
    own_plan = create(:shared_item, shared_relationship_space: space, creator: person)
    other_task = create(:shared_item, shared_relationship_space: space, creator: space.owner, kind: "task", parent: own_plan, assignee: person)
    person.destroy!
    expect(space.reload).to be_active
    expect(SharedItem.exists?(own_plan.id)).to be(false)
    expect(other_task.reload.parent).to be_nil
    expect(other_task.assignee).to be_nil
    expect(space.family_memberships).to be_empty
  end

  it "deletes all family content when the organizer deletes their account" do
    invite.accept!(person)
    item = create(:shared_item, shared_relationship_space: space, creator: person, category: "rsvp")
    item.family_responses.create!(user: person, attendance: "yes")
    space.owner.destroy!
    expect(SharedRelationshipSpace.exists?(space.id)).to be(false)
    expect(FamilyResponse.where(shared_item_id: item.id)).to be_empty
    expect(FamilyMembership.where(shared_relationship_space_id: space.id)).to be_empty
  end
  it "cancels a discovered reminder when membership is withdrawn before delivery" do
    membership = invite
    membership.accept!(person)
    item = create(:shared_item, shared_relationship_space: space, creator: space.owner, kind: "reminder", due_at: 1.minute.ago)
    subscription = item.shared_reminder_subscriptions.create!(user: person)
    discovered = SharedReminderSubscription.includes(:user, shared_item: :shared_relationship_space).find(subscription.id)
    membership.destroy!
    expect { DispatchSharedRemindersJob.new.send(:deliver, discovered) }.not_to change(Noticed::Notification, :count)
    expect { SharedSpaces::ChangeItem.call(space: space, actor: person, item: item, action: :subscribe) }.to raise_error(ActiveRecord::RecordNotFound)
  end
  it "rejects a second acceptance by an existing member after their email changes" do
    invite.accept!(person)
    person.skip_reconfirmation!
    person.update!(email: "changed-family-email@example.test")
    second_invitation = invite
    expect { second_invitation.accept!(person) }.to raise_error(ActiveRecord::RecordNotFound)
    expect(second_invitation.reload.user_id).to be_nil
    expect(space.family_memberships.where(user: person).count).to eq(1)
  end
end
