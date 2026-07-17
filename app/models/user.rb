# == Schema Information
#
# Table name: users
# Database name: primary
#
#  id                          :uuid             not null, primary key
#  admin                       :boolean          default(FALSE), not null
#  confirmation_sent_at        :datetime
#  confirmation_token          :string
#  confirmed_at                :datetime
#  current_sign_in_at          :datetime
#  current_sign_in_ip          :string
#  email                       :string           default(""), not null
#  encrypted_password          :string           default(""), not null
#  failed_attempts             :integer          default(0), not null
#  last_sign_in_at             :datetime
#  last_sign_in_ip             :string
#  locked_at                   :datetime
#  onboarding_completed_at     :datetime
#  onboarding_skipped_at       :datetime
#  privacy_vault_lease_version :integer          default(0), not null
#  provider                    :string
#  remember_created_at         :datetime
#  reset_password_sent_at      :datetime
#  reset_password_token        :string
#  sign_in_count               :integer          default(0), not null
#  uid                         :string
#  unconfirmed_email           :string
#  unlock_token                :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_provider_and_uid      (provider,uid) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :timeoutable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :trackable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"
  has_many :reminders, dependent: :destroy
  has_many :digest_deliveries, dependent: :destroy
  has_one :notification_preference, dependent: :destroy
  has_many :relationship_profiles, dependent: :destroy
  has_many :commitments, through: :relationship_profiles
  has_many :relationship_tags, dependent: :destroy
  has_many :relationship_groups, dependent: :destroy
  has_many :vault_access_events, dependent: :destroy

  def onboarding_completed?
    return true if onboarding_completed_at.present?
    return false unless persisted?

    relationship_profiles.exists?
  end

  def onboarding_pending?
    return false if onboarding_skipped_at.present?

    !onboarding_completed?
  end

  def onboarding_available?
    !onboarding_completed?
  end

  def skip_onboarding!
    return true if onboarding_completed?

    update!(onboarding_skipped_at: Time.current)
  end

  def complete_onboarding!
    update!(onboarding_completed_at: Time.current, onboarding_skipped_at: nil)
  end

  def self.from_google_oauth(auth)
    email = auth.info.email.to_s.downcase

    find_or_initialize_by(email:).tap do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.password = Devise.friendly_token.first(32) if user.encrypted_password.blank?
      user.skip_confirmation! if user.new_record?
      user.save!
    end
  end
end
