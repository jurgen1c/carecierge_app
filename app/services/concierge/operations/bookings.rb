module Concierge
  module Operations
    class Bookings < ManualPlanRecords
      CLEARABLE_FIELDS = %w[location confirmation_details cancellation_policy notes].freeze
      NAMESPACE = "bookings"
      ASSOCIATION = :bookings
      SEARCH = :title_or_provider_name_or_notes_cont
      FIELDS = { booking_kind: Booking::BOOKING_KINDS, title: :string, provider_name: :string,
        starts_at: :datetime, location: :string, status: Booking::STATUSES, confirmation_details: :string,
        cancellation_policy: :string, notes: :string }.freeze
      REQUIRED = %w[title provider_name starts_at].freeze

      def create
        record = user.bookings.new(event_plan: plan)
        authorize!(record, :create)
        ::Bookings::Save.call(record, attributes: record_attributes.merge(time_zone: OwnerLocalCalendar.time_zone_for(user:).name), locale: turn.locale)
        booking_result(record)
      end

      def update
        authorize!(target, :update)
        ::Bookings::Save.call(target, attributes: record_attributes, expected_lock_version: arguments.fetch("lock_version"), locale: turn.locale)
        booking_result(target)
      rescue ActiveRecord::StaleObjectError
        raise RequestConflict
      end

      def destroy
        authorize!(target, :destroy)
        value = record_receipt(target)
        removed = [ [ "PlanTask", target.plan_task_id ], [ "TimelineEntry", target.timeline_entry&.id ] ].filter_map do |type, id|
          { "record_type" => type, "id" => id } if id
        end
        ::Bookings::Destroy.call(target)
        { "record" => value, "deleted" => true, "superseded" => removed }
      end

      def record_receipt(record)
        receipt(record, title: record.title, body: record.notes, event_plan_id: plan.id,
          provider_name: record.provider_name, starts_at: record.local_starts_at.iso8601, time_zone: record.time_zone,
          state: record.status, location: record.location, confirmation_details: record.confirmation_details,
          cancellation_policy: record.cancellation_policy, lock_version: record.lock_version, manual_record: true)
      end

      private

      def booking_result(record)
        timeline = record.timeline_entry.reload
        records = [ Tasks.receipt_for(record.plan_task.reload) ]
        records << receipt(timeline, title: timeline.title, body: timeline.body) unless profile.professional?
        { "record" => record_receipt(record), "records" => records }
      end
    end
  end
end
