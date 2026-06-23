# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  locked_at              :datetime
#  provider               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  uid                    :string
#  unconfirmed_email      :string
#  unlock_token           :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_provider_and_uid      (provider,uid) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
require 'rails_helper'

RSpec.describe User, type: :model do
  it { is_expected.to have_many(:notifications).class_name("Noticed::Notification").dependent(:destroy) }
  it { is_expected.to validate_presence_of(:email) }

  describe ".from_google_oauth" do
    let(:auth) do
      OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "google-123",
        info: { email: "USER@example.com" }
      )
    end

    it "creates a confirmed user from Google OAuth data" do
      user = described_class.from_google_oauth(auth)

      expect(user).to be_persisted
      expect(user).to be_confirmed
      expect(user.email).to eq("user@example.com")
      expect(user.provider).to eq("google_oauth2")
      expect(user.uid).to eq("google-123")
    end

    it "updates OAuth identity for an existing user" do
      existing_user = create(:user, email: "user@example.com")

      user = described_class.from_google_oauth(auth)

      expect(user).to eq(existing_user)
      expect(user.provider).to eq("google_oauth2")
      expect(user.uid).to eq("google-123")
    end
  end

  describe "search and notification integration" do
    it "allows Ransack to search database-backed attributes and associations" do
      expect(described_class.ransackable_attributes).to include("email")
      expect(described_class.ransackable_associations).to include("notifications")
    end
  end
end
