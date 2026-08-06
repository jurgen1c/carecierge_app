# == Schema Information
#
# Table name: automation_permission_changes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  action                  :string           not null
#  capability              :string           not null
#  new_mode                :string
#  previous_mode           :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  actor_id                :uuid             not null
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_automation_permission_changes_relationship_time             (relationship_profile_id,created_at)
#  index_automation_permission_changes_on_actor_id                 (actor_id)
#  index_automation_permission_changes_on_relationship_profile_id  (relationship_profile_id)
#  index_automation_permission_changes_on_user_id                  (user_id)
#  index_automation_permission_changes_on_user_id_and_created_at   (user_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe AutomationPermissionChange, type: :model do
  it "is append-only once recorded" do
    change = create(:automation_permission_change)

    expect { change.update!(new_mode: "allow_automatically") }
      .to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { change.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "rejects capabilities outside the catalog" do
    change = build(:automation_permission_change, capability: "unknown")

    expect(change).not_to be_valid
  end

  it "preserves relationship scope after the relationship is deleted" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    change = create(:automation_permission_change, user:, actor: user, relationship_profile: profile)

    profile.destroy!

    expect(change.reload.relationship_profile_id).to eq(profile.id)
    expect(change.relationship_profile).to be_nil
  end

  it "does not prevent an owner from deleting an account with audit history" do
    user = create(:user)
    create(:automation_permission_change, user:, actor: user)

    expect { user.destroy! }.not_to raise_error
    expect(described_class.where(user_id: user.id)).to be_empty
  end

  it "requires the actor to be the permission owner" do
    change = build(:automation_permission_change, actor: create(:user))

    expect(change).not_to be_valid
    expect(change.errors[:actor]).to be_present
  end
end
