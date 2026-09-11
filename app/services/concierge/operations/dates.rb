module Concierge
  module Operations
    class Dates < ProfileRecords
      NAMESPACE = "dates"
      ASSOCIATION = :important_dates
      FIELDS = { date_type: ImportantDate::DATE_TYPES, title: :string, starts_on: :date,
        recurrence: ImportantDate::RECURRENCES, importance_level: ImportantDate::IMPORTANCE_LEVELS,
        reminder_schedule: ImportantDate::REMINDER_SCHEDULES, notes: :string }.freeze
      REQUIRED = %w[date_type starts_on].freeze
      SEARCH = :title_or_notes_cont
      TITLE = :display_title
      BODY = :notes

      def record_receipt(record)
        super.merge("next_occurrence_on" => record.next_occurrence_on&.iso8601)
      end
    end
  end
end
