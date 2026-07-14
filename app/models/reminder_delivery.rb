# == Schema Information
#
# Table name: reminder_deliveries
# Database name: primary
#
#  id            :uuid             not null, primary key
#  channel       :string           not null
#  dispatched_at :datetime
#  enqueued_at   :datetime
#  error_message :text
#  scheduled_for :datetime         not null
#  status        :string           default("pending"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  reminder_id   :uuid             not null
#
# Indexes
#
#  index_reminder_deliveries_on_occurrence_and_channel  (reminder_id,channel,scheduled_for) UNIQUE
#  index_reminder_deliveries_on_pending_enqueue_lease   (enqueued_at) WHERE ((status)::text = 'pending'::text)
#  index_reminder_deliveries_on_reminder_id             (reminder_id)
#
# Foreign Keys
#
#  fk_rails_...  (reminder_id => reminders.id) ON DELETE => cascade
#
class ReminderDelivery < ApplicationRecord
  CHANNELS = %w[in_app email].freeze
  STATUSES = %w[pending dispatched failed cancelled].freeze

  belongs_to :reminder

  validates :channel, inclusion: { in: CHANNELS }
  validates :scheduled_for, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :channel, uniqueness: { scope: [ :reminder_id, :scheduled_for ] }

  scope :pending, -> { where(status: "pending") }
  scope :recoverable, ->(before:) { pending.where(enqueued_at: nil).or(pending.where(enqueued_at: ..before)) }

  def dispatched?
    dispatched_at.present?
  end

  def pending?
    status == "pending"
  end

  def cancelled?
    status == "cancelled"
  end

  def current_occurrence?(current_reminder = reminder)
    current_reminder.active? && scheduled_for == current_reminder.effective_delivery_at
  end

  def cancel!
    update!(status: "cancelled", dispatched_at: nil, enqueued_at: nil, error_message: nil)
  end
end
