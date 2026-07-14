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
FactoryBot.define do
  factory :reminder_delivery do
    reminder
    channel { "in_app" }
    scheduled_for { reminder.next_delivery_at || reminder.scheduled_at }
    status { "pending" }
    dispatched_at { nil }
    error_message { nil }
  end
end
