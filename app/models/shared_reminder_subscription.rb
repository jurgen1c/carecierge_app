class SharedReminderSubscription < ApplicationRecord
  belongs_to :shared_item
  belongs_to :user
  scope :pending_delivery, -> {
    joins(:shared_item)
      .where(shared_items: { kind: "reminder", completed_at: nil })
      .where("shared_items.due_at <= ?", Time.current)
      .where("shared_reminder_subscriptions.delivered_for IS DISTINCT FROM shared_items.due_at")
  }

  validates :user_id, uniqueness: { scope: :shared_item_id }
  validate :eligible_participant

  private

  def eligible_participant
    item = shared_item
    return if item&.kind == "reminder" && !item.completed? && item.shared_relationship_space.active? && item.shared_relationship_space.participant?(user)

    errors.add(:base, :invalid)
  end
end
