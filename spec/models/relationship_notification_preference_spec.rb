# == Schema Information
#
# Table name: relationship_notification_preferences
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  mode                       :string           default("muted"), not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  notification_preference_id :uuid             not null
#  relationship_profile_id    :uuid             not null
#
# Indexes
#
#  idx_on_notification_preference_id_f719334035  (notification_preference_id)
#  idx_on_relationship_profile_id_ed7238d212     (relationship_profile_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (notification_preference_id => notification_preferences.id) ON DELETE => cascade
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe RelationshipNotificationPreference, type: :model do
  it "accepts a muted override for a relationship owned by the preference user" do
    user = create(:user)
    preference = create(:notification_preference, user:)
    override = build(
      :relationship_notification_preference,
      notification_preference: preference,
      relationship_profile: create(:relationship_profile, user:),
      mode: "muted"
    )

    expect(override).to be_valid
  end

  it "rejects a relationship owned by another user" do
    override = build(
      :relationship_notification_preference,
      notification_preference: create(:notification_preference),
      relationship_profile: create(:relationship_profile)
    )

    expect(override).not_to be_valid
    expect(override.errors[:relationship_profile]).to be_present
  end
end
