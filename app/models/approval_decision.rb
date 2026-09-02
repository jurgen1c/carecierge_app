# == Schema Information
#
# Table name: approval_decisions
# Database name: primary
#
#  id                  :uuid             not null, primary key
#  decision            :string           not null
#  occurred_at         :datetime         not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  approval_request_id :uuid             not null
#  user_id             :uuid             not null
#
# Indexes
#
#  idx_on_approval_request_id_occurred_at_2164c1d00e  (approval_request_id,occurred_at)
#  index_approval_decisions_on_approval_request_id    (approval_request_id)
#  index_approval_decisions_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (approval_request_id => approval_requests.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
class ApprovalDecision < ApplicationRecord
  DECISIONS = %w[approve reject edit defer dismiss].freeze

  belongs_to :approval_request
  belongs_to :user

  validates :decision, inclusion: { in: DECISIONS }
  validates :occurred_at, presence: true
  validate :user_owns_request

  def readonly?
    persisted?
  end

  private

  def user_owns_request
    return if user.blank? || approval_request.blank? || user_id == approval_request.user_id

    errors.add(:user, :owner_mismatch)
  end
end
