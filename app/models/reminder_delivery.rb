# == Schema Information
#
# Table name: reminder_deliveries
# Database name: primary
#
#  id               :uuid             not null, primary key
#  channel          :string           not null
#  dispatched_at    :datetime
#  enqueued_at      :datetime
#  error_message    :text
#  lease_token      :uuid
#  scheduled_for    :datetime         not null
#  status           :string           default("pending"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  noticed_event_id :uuid
#  reminder_id      :uuid             not null
#
# Indexes
#
#  index_reminder_deliveries_on_noticed_event_id        (noticed_event_id) UNIQUE
#  index_reminder_deliveries_on_occurrence_and_channel  (reminder_id,channel,scheduled_for) UNIQUE
#  index_reminder_deliveries_on_recoverable_lease       (enqueued_at) WHERE ((status)::text = ANY ((ARRAY['pending'::character varying, 'dispatching'::character varying])::text[]))
#  index_reminder_deliveries_on_reminder_id             (reminder_id)
#
# Foreign Keys
#
#  fk_rails_...  (noticed_event_id => noticed_events.id) ON DELETE => nullify
#  fk_rails_...  (reminder_id => reminders.id) ON DELETE => cascade
#
class ReminderDelivery < ApplicationRecord
  CHANNELS = %w[in_app email].freeze
  STATUSES = %w[pending dispatching dispatched failed cancelled].freeze

  belongs_to :reminder
  belongs_to :noticed_event, class_name: "Noticed::Event", optional: true

  validates :channel, inclusion: { in: CHANNELS }
  validates :scheduled_for, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :channel, uniqueness: { scope: [ :reminder_id, :scheduled_for ] }

  scope :pending, -> { where(status: "pending") }
  scope :recoverable, lambda { |before:|
    where(status: "pending", enqueued_at: nil)
      .or(where(status: %w[pending dispatching], enqueued_at: ..before))
  }

  def dispatched?
    dispatched_at.present?
  end

  def pending?
    status == "pending"
  end

  def dispatching?
    status == "dispatching"
  end

  def recoverable?(before:)
    (pending? && (enqueued_at.nil? || enqueued_at <= before)) ||
      (dispatching? && enqueued_at.present? && enqueued_at <= before)
  end

  def cancelled?
    status == "cancelled"
  end

  def current_occurrence?(current_reminder = reminder)
    current_reminder.active? && scheduled_for == current_reminder.effective_delivery_at
  end

  def cancel!
    transaction do
      noticed_event&.destroy!
      update!(status: "cancelled", dispatched_at: nil, enqueued_at: nil, lease_token: nil, error_message: nil)
    end
  end

  def revive!
    return self unless cancelled?

    update!(status: "pending", dispatched_at: nil, enqueued_at: nil, lease_token: nil, error_message: nil)
    self
  end

  def with_processing_lock
    acquired = false
    result = false

    self.class.connection_pool.with_connection do |connection|
      lock_expression = "hashtextextended(#{connection.quote(id)}, 0)"
      acquired = ActiveModel::Type::Boolean.new.cast(
        connection.select_value("SELECT pg_try_advisory_lock(#{lock_expression})")
      )
      next unless acquired

      begin
        result = yield
      ensure
        connection.select_value("SELECT pg_advisory_unlock(#{lock_expression})")
      end
    end

    result
  end
end
