# == Schema Information
#
# Table name: contacts_connections
# Database name: primary
#
#  id                :uuid             not null, primary key
#  access_token      :text
#  last_refreshed_at :datetime
#  next_page_token   :text
#  provider          :string           default("google_contacts"), not null
#  refresh_token     :text
#  status            :string           default("connected"), not null
#  token_expires_at  :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  user_id           :uuid             not null
#
# Indexes
#
#  index_contacts_connections_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ContactsConnection < ApplicationRecord
  GOOGLE_SCOPE = "https://www.googleapis.com/auth/contacts.readonly"
  belongs_to :user
  has_many :imported_contacts, dependent: :destroy
  encrypts :access_token, :refresh_token, :next_page_token
  validates :provider, inclusion: { in: %w[google_contacts] }
  validates :status, inclusion: { in: %w[connected cleanup_required authorization_required] }
  validates :user_id, uniqueness: true

  def credentials
    Contacts::GoogleOauth::Credentials.new(access_token:, refresh_token:, expires_at: token_expires_at, scopes: [ GOOGLE_SCOPE ])
  end
end
