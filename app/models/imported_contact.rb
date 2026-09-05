# == Schema Information
#
# Table name: imported_contacts
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  applied_data            :text
#  data                    :text             not null
#  decision                :string           default("pending"), not null
#  lock_version            :integer          default(0), not null
#  previous_data           :text
#  provider_key            :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  contacts_connection_id  :uuid             not null
#  external_id             :text             not null
#  relationship_profile_id :uuid
#
# Indexes
#
#  idx_on_contacts_connection_id_provider_key_a5445e4db7  (contacts_connection_id,provider_key) UNIQUE
#  index_imported_contacts_on_contacts_connection_id      (contacts_connection_id)
#  index_imported_contacts_on_relationship_profile_id     (relationship_profile_id)
#
# Foreign Keys
#
#  fk_rails_...  (contacts_connection_id => contacts_connections.id)
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => nullify
#
class ImportedContact < ApplicationRecord
  belongs_to :contacts_connection
  belongs_to :relationship_profile, optional: true
  serialize :data, coder: JSON
  serialize :applied_data, coder: JSON
  serialize :previous_data, coder: JSON
  encrypts :external_id, :data, :applied_data, :previous_data
  validates :provider_key, :external_id, presence: true
  validates :decision, inclusion: { in: %w[pending skip create link update] }
  validates :provider_key, uniqueness: { scope: :contacts_connection_id }
  validate :profile_owner

  def display_name = [ data["first_name"], data["last_name"] ].compact_blank.join(" ")
  def user = contacts_connection.user

  private

  def profile_owner
    errors.add(:relationship_profile, :invalid) if relationship_profile && relationship_profile.user_id != user.id
  end
end
