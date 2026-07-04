# == Schema Information
#
# Table name: relationship_groups
# Database name: primary
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :uuid             not null
#
# Indexes
#
#  index_relationship_groups_on_user_id                 (user_id)
#  index_relationship_groups_on_user_id_and_lower_name  (user_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe RelationshipGroup, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:relationship_group_memberships).dependent(:destroy) }
  it { is_expected.to have_many(:relationship_profiles).through(:relationship_group_memberships) }
  it { is_expected.to validate_presence_of(:name) }

  it "normalizes names and keeps them unique per user" do
    user = create(:user)
    create(:relationship_group, user:, name: "Close family")
    group = build(:relationship_group, user:, name: " close family ")

    expect(group).not_to be_valid
    expect(group.errors[:name]).to include("has already been taken")
    expect(group.name).to eq("close family")
  end

  it "allows different users to reuse the same group name" do
    create(:relationship_group, name: "close family")
    group = build(:relationship_group, name: "close family")

    expect(group).to be_valid
  end
end
