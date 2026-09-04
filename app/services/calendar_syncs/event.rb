module CalendarSyncs
  class Event
    SYNC_TYPE_BY_CLASS = {
      "ImportantDate" => "important_dates",
      "Reminder" => "reminders",
      "EventPlan" => "event_plans",
      "Booking" => "bookings",
      "Commitment" => "commitments"
    }.freeze
    FREQUENCIES = {
      "daily" => "DAILY",
      "weekly" => "WEEKLY",
      "monthly" => "MONTHLY",
      "yearly" => "YEARLY"
    }.freeze
    RECURRENCE_HORIZON = 100.years

    attr_reader :locale, :source

    def initialize(source:, locale: I18n.default_locale)
      @source = source
      @locale = locale.to_sym
    end

    def sync_type = SYNC_TYPE_BY_CLASS.fetch(source.class.base_class.name)

    def attributes
      @attributes ||= {
        summary: title,
        description: "Carecierge",
        visibility: "private",
        transparency: "transparent",
        start:,
        end: finish
      }.tap do |payload|
        payload[:recurrence] = recurrence if recurrence.any?
      end
    end

    def fingerprint = Digest::SHA256.hexdigest(JSON.generate(attributes))

    private

    def title
      source.is_a?(ImportantDate) ? I18n.with_locale(locale) { source.display_title } : source.title
    end

    def start
      case source
      when ImportantDate then { date: source.starts_on.iso8601 }
      when EventPlan then { date: source.starts_on.iso8601 }
      when Commitment then { date: source.due_on.iso8601 }
      when Booking then timed_value(source.starts_at, source.time_zone)
      when Reminder then timed_value(reminder_time, source.time_zone)
      end
    end

    def finish
      case source
      when ImportantDate then { date: source.starts_on.next_day.iso8601 }
      when EventPlan then { date: source.starts_on.next_day.iso8601 }
      when Commitment then { date: source.due_on.next_day.iso8601 }
      when Booking then timed_value(source.starts_at + 1.hour, source.time_zone)
      when Reminder then timed_value(reminder_time + 30.minutes, source.time_zone)
      end
    end

    def timed_value(value, time_zone)
      zone = ActiveSupport::TimeZone[time_zone] || ActiveSupport::TimeZone["UTC"]
      { date_time: value.in_time_zone(zone).iso8601, time_zone: zone.tzinfo.name }
    end

    def recurrence
      return clamped_important_date_recurrence if clamped_important_date?
      return clamped_reminder_recurrence if clamped_reminder?

      frequency = source.respond_to?(:recurrence) && FREQUENCIES[source.recurrence]
      frequency ? [ "RRULE:FREQ=#{frequency}" ] : []
    end

    def reminder_time
      source.recurrence == "none" ? source.effective_delivery_at : source.scheduled_at
    end

    def clamped_important_date?
      source.is_a?(ImportantDate) &&
        (source.recurrence == "monthly" && source.starts_on.day > 28 ||
          source.recurrence == "yearly" && source.starts_on.month == 2 && source.starts_on.day == 29)
    end

    def clamped_important_date_recurrence
      horizon = source.starts_on + RECURRENCE_HORIZON
      occurrences = []
      reference_date = source.starts_on.next_day
      if horizon < Date.current
        reference_date = Date.current
        horizon = Date.current + RECURRENCE_HORIZON
      end
      while (occurrence = source.next_occurrence_on(as_of: reference_date)) && occurrence <= horizon
        occurrences << occurrence.strftime("%Y%m%d")
        reference_date = occurrence.next_day
      end
      [ "RDATE;VALUE=DATE:#{occurrences.join(',')}" ]
    end

    def clamped_reminder?
      return false unless source.is_a?(Reminder)

      anchor = source.recurrence_anchor_at.in_time_zone(source.time_zone)
      source.recurrence == "monthly" && anchor.day > 28 ||
        source.recurrence == "yearly" && anchor.month == 2 && anchor.day == 29
    end

    def clamped_reminder_recurrence
      zone = ActiveSupport::TimeZone[source.time_zone] || ActiveSupport::TimeZone["UTC"]
      anchor = source.recurrence_anchor_at.in_time_zone(zone)
      current = source.scheduled_at.in_time_zone(zone)
      horizon = anchor + RECURRENCE_HORIZON
      if horizon < Time.current
        current = Time.current.in_time_zone(zone)
        horizon = current + RECURRENCE_HORIZON
      end
      interval = 1
      occurrences = []
      while (occurrence = advance_reminder_occurrence(anchor, interval)) <= horizon
        occurrences << occurrence.utc.strftime("%Y%m%dT%H%M%SZ") if occurrence > current
        interval += 1
      end
      [ "RDATE:#{occurrences.join(',')}" ]
    end

    def advance_reminder_occurrence(anchor, interval)
      source.recurrence == "monthly" ? anchor.advance(months: interval) : anchor.advance(years: interval)
    end
  end
end
