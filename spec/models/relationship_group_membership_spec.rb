# == Schema Information
#
# Table name: relationship_group_memberships
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_group_id   :uuid             not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  idx_on_relationship_profile_id_5e33b2c4bc                      (relationship_profile_id)
#  index_relationship_group_memberships_on_profile_and_group      (relationship_profile_id,relationship_group_id) UNIQUE
#  index_relationship_group_memberships_on_relationship_group_id  (relationship_group_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_group_id => relationship_groups.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe RelationshipGroupMembership, type: :model do
  it { is_expected.to belong_to(:relationship_profile) }
  it { is_expected.to belong_to(:relationship_group) }

  it "uses a submitted group name to assign a reusable user-owned group" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    membership = profile.relationship_group_memberships.build(group_name: " Neighbors ")

    expect(membership).to be_valid
    expect(membership.relationship_group).to have_attributes(user:, name: "Neighbors")
  end
end
