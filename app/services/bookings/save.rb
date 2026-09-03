module Bookings
  class Save
    def self.call(booking, attributes:, expected_lock_version: nil, locale: I18n.locale)
      new(booking, attributes:, expected_lock_version:, locale:).call
    end

    def initialize(booking, attributes:, expected_lock_version:, locale:)
      @booking = booking
      @attributes = attributes
      @expected_lock_version = expected_lock_version
      @locale = locale
    end

    def call
      Booking.transaction do
        booking.user.with_lock("FOR NO KEY UPDATE") do
          booking.event_plan.relationship_profile.with_lock do
            booking.event_plan.with_lock do
              raise ActiveRecord::RecordNotFound unless booking.mutable?

              persist_booking!
              sync_plan_task!
              retire_obsolete_booking_reminders!
              sync_timeline_entry!
            end
          end
        end
      end
      booking
    end

    private

    attr_reader :booking, :attributes, :expected_lock_version, :locale

    def persist_booking!
      if booking.persisted?
        booking.lock!
        if expected_lock_version && booking.lock_version != expected_lock_version
          raise ActiveRecord::StaleObjectError.new(booking, "update")
        end
        booking.update!(attributes) if attributes.present?
      else
        booking.assign_attributes(attributes)
        booking.save!
      end
    end

    def sync_plan_task!
      task = booking.plan_task || booking.event_plan.plan_tasks.build(
        kind: "vendor_need",
        phase: "arrange",
        origin: "manual",
        source_context: [],
        position: next_task_position
      )
      completed_at = Booking::TERMINAL_TASK_STATUSES.include?(booking.status) ? (task.completed_at || Time.current) : nil
      completing_task = completed_at.present? && !task.completed?
      task_title = I18n.with_locale(locale) { I18n.t("bookings.plan_task_title", title: booking.title) }
      task.assign_attributes(
        title: task_title.truncate(PlanTask::MAX_TITLE_LENGTH, omission: ""),
        due_on: booking.local_starts_at&.to_date,
        completed_at:
      )
      task_changed = task.new_record? || task.changed?
      task.save!
      task.reminders.active.order(:id).each(&:retire!) if completing_task
      booking.update!(plan_task: task) unless booking.plan_task_id == task.id
      booking.event_plan.increment!(:generation_version) if task_changed
    end

    def sync_timeline_entry!
      timeline_entry = booking.timeline_entry || booking.build_timeline_entry(
        relationship_profile: booking.event_plan.relationship_profile
      )
      timeline_entry.assign_attributes(
        entry_type: "booking",
        origin: "system",
        title: I18n.with_locale(locale) { I18n.t("bookings.timeline_title") },
        body: I18n.with_locale(locale) { booking.status_label },
        occurred_at: booking.starts_at
      )
      timeline_entry.save!
    end

    def retire_obsolete_booking_reminders!
      booking.reminders.active
        .where(booking_milestone: booking.obsolete_reminder_milestones)
        .order(:id)
        .each(&:retire!)
    end

    def next_task_position
      (booking.event_plan.plan_tasks.maximum(:position) || -1) + 1
    end
  end
end
