class ReminderCalendarSerializer
  PRODUCT_ID = "-//Carecierge//Reminders//EN"
  TIME_ZONE_HORIZON = 100.years
  FREQUENCIES = {
    "daily" => "DAILY",
    "weekly" => "WEEKLY",
    "monthly" => "MONTHLY",
    "yearly" => "YEARLY"
  }.freeze

  def initialize(reminders)
    @reminders = Array(reminders)
  end

  def to_ical
    lines = [ "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:#{PRODUCT_ID}", "CALSCALE:GREGORIAN" ]
    recurring_time_zones.each { |time_zone| lines.concat(time_zone_lines(time_zone)) }
    reminders.each { |reminder| lines.concat(event_lines(reminder)) }
    lines << "END:VCALENDAR"
    lines.flat_map { |line| fold_line(line) }.join("\r\n") + "\r\n"
  end

  private

  attr_reader :reminders

  def recurring_time_zones
    reminders.filter_map do |reminder|
      reminder.time_zone if FREQUENCIES.key?(reminder.recurrence) && reminder.time_zone != "UTC"
    end.uniq
  end

  def time_zone_lines(time_zone)
    zone = ActiveSupport::TimeZone[time_zone]
    related_reminders = reminders.select do |reminder|
      reminder.time_zone == time_zone && FREQUENCIES.key?(reminder.recurrence)
    end
    starts_at = related_reminders.map(&:scheduled_at).min
    ends_at = related_reminders.map(&:scheduled_at).max + TIME_ZONE_HORIZON
    transitions = zone.tzinfo.transitions_up_to(ends_at, starts_at - 1.year)

    lines = [ "BEGIN:VTIMEZONE", "TZID:#{time_zone}", "X-LIC-LOCATION:#{time_zone}" ]
    if transitions.empty?
      period = zone.tzinfo.period_for_utc(starts_at)
      lines.concat(period_lines("STANDARD", starts_at.in_time_zone(zone), period.utc_total_offset, period.utc_total_offset, period.abbreviation))
    else
      transitions.each do |transition|
        kind = transition.offset.std_offset.zero? ? "STANDARD" : "DAYLIGHT"
        local_onset = (transition.at.to_time + transition.previous_offset.utc_total_offset).in_time_zone("UTC")
        lines.concat(period_lines(
          kind,
          local_onset,
          transition.previous_offset.utc_total_offset,
          transition.offset.utc_total_offset,
          transition.offset.abbreviation
        ))
      end
    end
    lines << "END:VTIMEZONE"
    lines
  end

  def period_lines(kind, starts_at, offset_from, offset_to, name)
    [
      "BEGIN:#{kind}",
      "DTSTART:#{starts_at.strftime('%Y%m%dT%H%M%S')}",
      "TZOFFSETFROM:#{ical_offset(offset_from)}",
      "TZOFFSETTO:#{ical_offset(offset_to)}",
      "TZNAME:#{name}",
      "END:#{kind}"
    ]
  end

  def ical_offset(seconds)
    sign = seconds.negative? ? "-" : "+"
    hours, remainder = seconds.abs.divmod(1.hour)
    minutes = remainder / 1.minute
    format("%s%02d%02d", sign, hours, minutes)
  end

  def event_lines(reminder)
    starts_at, ends_at = calendar_times(reminder)
    lines = [
      "BEGIN:VEVENT",
      "UID:reminder-#{reminder.id}@carecierge",
      "DTSTAMP:#{ical_time(Time.current)}",
      starts_at,
      ends_at,
      "SUMMARY:#{escape_text(reminder.title)}",
      "CLASS:PRIVATE"
    ]
    lines << "DESCRIPTION:#{escape_text(reminder.notes)}" if reminder.notes.present?
    lines << "RRULE:FREQ=#{FREQUENCIES.fetch(reminder.recurrence)}" if FREQUENCIES.key?(reminder.recurrence)
    lines << "END:VEVENT"
    lines
  end

  def ical_time(time)
    time.utc.strftime("%Y%m%dT%H%M%SZ")
  end

  def calendar_times(reminder)
    if FREQUENCIES.key?(reminder.recurrence) && reminder.time_zone != "UTC"
      local_time = reminder.scheduled_at.in_time_zone(reminder.time_zone)
      prefix = "TZID=#{reminder.time_zone}"
      [
        "DTSTART;#{prefix}:#{local_time.strftime('%Y%m%dT%H%M%S')}",
        "DTEND;#{prefix}:#{(local_time + 30.minutes).strftime('%Y%m%dT%H%M%S')}"
      ]
    else
      delivery_time = reminder.recurrence == "none" ? reminder.effective_delivery_at : reminder.scheduled_at
      [
        "DTSTART:#{ical_time(delivery_time)}",
        "DTEND:#{ical_time(delivery_time + 30.minutes)}"
      ]
    end
  end

  def escape_text(value)
    value.to_s.gsub(/\r\n?|\n/, "\n").gsub("\\", "\\\\").gsub("\n", "\\n").gsub(",", "\\,").gsub(";", "\\;")
  end

  def fold_line(line)
    bytes = line.b
    return [ line ] if bytes.bytesize <= 75

    chunks = []
    first = true
    until bytes.empty?
      limit = first ? 75 : 74
      chunk = bytes.byteslice(0, limit)
      chunk = chunk.byteslice(0, chunk.bytesize - 1) until chunk.dup.force_encoding(Encoding::UTF_8).valid_encoding?
      chunks << "#{first ? nil : " "}#{chunk.force_encoding(Encoding::UTF_8)}"
      bytes = bytes.byteslice(chunk.bytesize..).to_s.b
      first = false
    end
    chunks
  end
end
