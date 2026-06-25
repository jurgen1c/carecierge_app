# == Schema Information
#
# Table name: feature_flag_assignments
# Database name: primary
#
#  id              :uuid             not null, primary key
#  enabled         :boolean          default(TRUE), not null
#  metadata        :jsonb            not null
#  target_kind     :string           not null
#  target_value    :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  feature_flag_id :uuid             not null
#
# Indexes
#
#  index_feature_flag_assignments_on_feature_flag_id               (feature_flag_id)
#  index_feature_flag_assignments_on_flag_and_target               (feature_flag_id,target_kind,target_value) UNIQUE
#  index_feature_flag_assignments_on_target_kind_and_target_value  (target_kind,target_value)
#
# Foreign Keys
#
#  fk_rails_...  (feature_flag_id => feature_flags.id)
#
require "rails_helper"

RSpec.describe FeatureFlagAssignment, type: :model do
  it "requires global assignments to target all" do
    assignment = build(:feature_flag_assignment, target_kind: "global", target_value: "everyone")

    expect(assignment).not_to be_valid
    expect(assignment.errors[:target_value]).to include("must be all for global assignments")
  end

  it "allows the supported global assignment target" do
    assignment = build(:feature_flag_assignment, target_kind: "global", target_value: "all")

    expect(assignment).to be_valid
  end
end
