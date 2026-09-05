require "rails_helper"

RSpec.describe SharedRelationshipSpace, type: :model do
  it "requires confirmed, distinct invited accounts and stores private input encrypted" do
    space = build(:shared_relationship_space)
    space.partner = nil
    space.accepted_at = nil
    recipient = create(:user, email: space.invited_email)
    recipient.update_columns(confirmed_at: nil)
    expect(space.can_accept?(recipient)).to be(false)
    recipient.update_columns(confirmed_at: Time.current)
    expect(space.can_accept?(recipient)).to be(true)
    space.invited_email = space.owner.email
    expect(space).not_to be_valid
    space.invited_email = recipient.email
    space.save!
    expect(space.title_before_type_cast).not_to include(space.title)
    expect(space.invited_email_before_type_cast).not_to include(recipient.email)
  end

  it "deletes the workspace for either participant's account deletion" do
    space = create(:shared_relationship_space)
    item = create(:shared_item, shared_relationship_space: space)
    space.partner.destroy!
    expect(described_class.exists?(space.id)).to be(false)
    expect(SharedItem.exists?(item.id)).to be(false)
  end
  [ :owner, :partner ].each do |role|
    it "deletes nested shared items when the #{role} account is deleted" do
      space = create(:shared_relationship_space)
      plan = create(:shared_item, shared_relationship_space: space)
      create(:shared_item, shared_relationship_space: space, kind: "task", parent: plan)
      expect { space.public_send(role).destroy! }.to change(SharedItem, :count).by(-2)
      expect(described_class.exists?(space.id)).to be(false)
    end
  end

  it "ends sharing with a plan and nested task regardless of creation order" do
    space = create(:shared_relationship_space)
    plan = create(:shared_item, shared_relationship_space: space)
    create(:shared_item, shared_relationship_space: space, kind: "task", parent: plan)
    expect { space.end_sharing!(space.partner) }.to change(SharedItem, :count).by(-2)
  end
end
