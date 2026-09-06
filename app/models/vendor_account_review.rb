# == Schema Information
#
# Table name: vendor_account_reviews
# Database name: primary
#
#  id                :uuid             not null, primary key
#  from_status       :string           not null
#  profile_snapshot  :text             not null
#  profile_version   :integer          not null
#  reason            :text
#  to_status         :string           not null
#  created_at        :datetime         not null
#  actor_id          :uuid
#  vendor_account_id :uuid             not null
#
# Indexes
#
#  idx_on_vendor_account_id_created_at_bfff056fe8     (vendor_account_id,created_at)
#  index_vendor_account_reviews_on_actor_id           (actor_id)
#  index_vendor_account_reviews_on_vendor_account_id  (vendor_account_id)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id) ON DELETE => nullify
#  fk_rails_...  (vendor_account_id => vendor_accounts.id) ON DELETE => cascade
#
class VendorAccountReview < ApplicationRecord
  belongs_to :vendor_account, inverse_of: :reviews
  belongs_to :actor, class_name: "User", optional: true

  serialize :profile_snapshot, coder: JSON
  encrypts :profile_snapshot, :reason

  validates :from_status, :to_status, inclusion: { in: VendorAccount::STATUSES }
  validates :profile_version, :profile_snapshot, presence: true
  validates :reason, length: { maximum: 1_000 }
  validates :reason, presence: true, if: -> { to_status.in?(%w[rejected suspended]) }

  def readonly? = persisted?
end
