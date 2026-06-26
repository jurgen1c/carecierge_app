# == Schema Information
#
# Table name: relationship_types
# Database name: primary
#
#  id          :uuid             not null, primary key
#  active      :boolean          default(TRUE), not null
#  description :text
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :uuid             not null
#
# Indexes
#
#  index_relationship_types_on_id_and_user_id          (id,user_id) UNIQUE
#  index_relationship_types_on_user_id                 (user_id)
#  index_relationship_types_on_user_id_and_lower_name  (user_id, lower((name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe RelationshipType, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:relationship_profiles).dependent(:restrict_with_exception) }
  it { is_expected.to validate_presence_of(:name) }

  it "does not allow duplicate type names for the same user" do
    user = create(:user)
    create(:relationship_type, user:, name: "Friend")

    duplicate = build(:relationship_type, user:, name: "Friend")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end
end
