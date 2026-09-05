class FamilyResponse < ApplicationRecord
  ATTENDANCES = %w[yes maybe no].freeze
  belongs_to :shared_item
  belongs_to :user
  validates :attendance, inclusion: { in: ATTENDANCES }
  validates :user_id, uniqueness: { scope: :shared_item_id }
  validate :eligible_response

  private

  def eligible_response
    item = shared_item
    return if item&.category == "rsvp" && item.kind == "plan" && !item.completed? &&
      item.shared_relationship_space.family? && item.shared_relationship_space.participant?(user)

    errors.add(:base, :invalid)
  end
end
