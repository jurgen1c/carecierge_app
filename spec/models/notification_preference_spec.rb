# == Schema Information
#
# Table name: notification_preferences
# Database name: primary
#
#  id             :uuid             not null, primary key
#  email_enabled  :boolean          default(TRUE), not null
#  in_app_enabled :boolean          default(TRUE), not null
#  push_enabled   :boolean          default(FALSE), not null
#  sms_enabled    :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :uuid             not null
#
# Indexes
#
#  index_notification_preferences_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe NotificationPreference, type: :model do
  it "defaults to enabled in-app and email delivery while reserving future channels" do
    preference = described_class.new

    expect(preference).to have_attributes(
      in_app_enabled: true,
      email_enabled: true,
      push_enabled: false,
      sms_enabled: false
    )
  end

  describe ".channels_for" do
    it "uses enabled defaults before a user saves preferences" do
      user = create(:user)

      expect(described_class.channels_for(user)).to eq(%w[in_app email])
    end

    it "returns only saved enabled channels" do
      user = create(:user)
      create(:notification_preference, user:, in_app_enabled: true, email_enabled: false)

      expect(described_class.channels_for(user)).to eq([ "in_app" ])
    end

    it "does not dispatch reserved future channels" do
      user = create(:user)
      create(:notification_preference, user:, push_enabled: true, sms_enabled: true)

      expect(described_class.channels_for(user)).to eq(%w[in_app email])
    end

    it "uses a preloaded preference without querying again" do
      user = create(:user)
      create(:notification_preference, user:, email_enabled: false)
      loaded_user = User.includes(:notification_preference).find(user.id)

      expect(described_class).not_to receive(:find_by)
      expect(described_class.channels_for(loaded_user)).to eq([ "in_app" ])
    end
  end
end
