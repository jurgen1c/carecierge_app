module DataExports
  class CalendarSerializer
    RECURRENCE_HORIZON = 100.years
    FREQUENCIES = {
      "weekly" => "WEEKLY",
      "monthly" => "MONTHLY",
      "yearly" => "YEARLY"
    }.freeze

    def initialize(reminders:, important_dates:)
      @reminders = reminders
      @important_dates = important_dates
    end

    def to_ical
      calendar = ReminderCalendarSerializer.new(reminders).to_ical
      date_lines = important_dates.flat_map { |important_date| event_lines(important_date) }
      calendar.sub("END:VCALENDAR\r\n", fold_lines(date_lines).join("\r\n") + "\r\nEND:VCALENDAR\r\n")
    end

    private

    attr_reader :reminders, :important_dates

    def event_lines(important_date)
      lines = [
        "BEGIN:VEVENT",
        "UID:important-date-#{important_date.id}@carecierge",
        "DTSTAMP:#{Time.current.utc.strftime('%Y%m%dT%H%M%SZ')}",
        "DTSTART;VALUE=DATE:#{important_date.starts_on.strftime('%Y%m%d')}",
        "DTEND;VALUE=DATE:#{important_date.starts_on.next_day.strftime('%Y%m%d')}",
        "SUMMARY:#{escape_text(important_date.display_title)}",
        "CLASS:PRIVATE"
      ]
      lines << "DESCRIPTION:#{escape_text(important_date.notes)}" if important_date.notes.present?
      lines.concat(recurrence_lines(important_date))
      lines << "END:VEVENT"
    end

    def recurrence_lines(important_date)
      return [] unless FREQUENCIES.key?(important_date.recurrence)
      return [ "RRULE:FREQ=#{FREQUENCIES.fetch(important_date.recurrence)}" ] unless clamped_recurrence?(important_date)

      occurrences = clamped_occurrences(important_date).drop(1).map { |date| date.strftime("%Y%m%d") }
      [ "RDATE;VALUE=DATE:#{occurrences.join(',')}" ]
    end

    def clamped_recurrence?(important_date)
      (important_date.recurrence == "monthly" && important_date.starts_on.day > 28) ||
        (important_date.recurrence == "yearly" && important_date.starts_on.month == 2 && important_date.starts_on.day == 29)
    end

    def clamped_occurrences(important_date)
      horizon = important_date.starts_on + RECURRENCE_HORIZON
      occurrences = [ important_date.starts_on ]

      loop do
        occurrence = important_date.next_occurrence_on(as_of: occurrences.last.next_day)
        break if occurrence.nil? || occurrence > horizon

        occurrences << occurrence
      end

      occurrences
    end

    def escape_text(value)
      value.to_s.gsub(/\r\n?|\n/, "\n").gsub("\\", "\\\\").gsub("\n", "\\n").gsub(",", "\\,").gsub(";", "\\;")
    end

    def fold_lines(lines)
      lines.flat_map do |line|
        bytes = line.b
        chunks = []
        first = true
        until bytes.empty?
          limit = first ? 75 : 74
          chunk = bytes.byteslice(0, limit)
          chunk = chunk.byteslice(0, chunk.bytesize - 1) until chunk.dup.force_encoding(Encoding::UTF_8).valid_encoding?
          chunks << "#{first ? nil : ' '}#{chunk.force_encoding(Encoding::UTF_8)}"
          bytes = bytes.byteslice(chunk.bytesize..).to_s.b
          first = false
        end
        chunks
      end
    end
  end
end
