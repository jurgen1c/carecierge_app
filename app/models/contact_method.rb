# == Schema Information
#
# Table name: contact_methods
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  kind                    :string           not null
#  label                   :string
#  preferred               :boolean          default(FALSE), not null
#  value                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_contact_methods_on_relationship_profile_id           (relationship_profile_id)
#  index_contact_methods_on_relationship_profile_id_and_kind  (relationship_profile_id,kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
class ContactMethod < ApplicationRecord
  enum :kind, {
    email: "email",
    personal_email: "personal_email",
    business_email: "business_email",
    phone: "phone",
    personal_phone: "personal_phone",
    business_phone: "business_phone"
  }

  belongs_to :relationship_profile

  validates :kind, presence: true
  validates :value, presence: true
  validates :kind, uniqueness: { scope: :relationship_profile_id }
end
