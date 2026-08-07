module AuditEvents
  class Query
    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
    SUPPORTED_YEAR_RANGE = (1..9999).freeze

    attr_reader :action, :occurred_from, :occurred_to, :source, :user_id

    def initialize(scope, filters:, time_zone: Time.zone)
      @scope = scope
      @filters = filters.to_h.stringify_keys
      @time_zone = normalize_time_zone(time_zone)
      @invalid = false
      normalize_filters
    end

    def resolve
      return scope.none if invalid?

      relation = scope
      relation = relation.where(user_id:) if user_id
      relation = relation.where(action:) if action
      relation = relation.where(source:) if source
      relation = relation.where(occurred_at: local_day_start(occurred_from)..) if occurred_from
      relation = relation.where(occurred_at: ..local_day_end(occurred_to)) if occurred_to
      relation.includes(:actor, :target, :user).recent_first
    end

    def filtered?
      filters.values.any? { |value| filter_submitted?(value) }
    end

    private

    attr_reader :filters, :scope, :time_zone

    def invalid?
      @invalid
    end

    def normalize_filters
      @user_id = normalize_uuid(filters["user_id"])
      @action = normalize_catalog_value(filters["event_action"], AuditEvent::ACTIONS)
      @source = normalize_catalog_value(filters["source"], AuditEvent::SOURCES)
      @occurred_from = normalize_date(filters["occurred_from"])
      @occurred_to = normalize_date(filters["occurred_to"])
      @invalid = true if occurred_from && occurred_to && occurred_from > occurred_to
    end

    def normalize_uuid(value)
      return unless filter_submitted?(value)
      return invalidate unless value.is_a?(String)

      normalized = value.downcase
      return normalized if normalized.match?(UUID_PATTERN)

      invalidate
    end

    def normalize_catalog_value(value, catalog)
      return unless filter_submitted?(value)
      return invalidate unless value.is_a?(String)
      return value if value.in?(catalog)

      invalidate
    end

    def normalize_date(value)
      return unless filter_submitted?(value)
      return invalidate unless value.is_a?(String)

      date = Date.iso8601(value)
      return date if SUPPORTED_YEAR_RANGE.cover?(date.year)

      invalidate
    rescue Date::Error
      invalidate
    end

    def filter_submitted?(value)
      !value.nil? && value != ""
    end

    def invalidate
      @invalid = true
      nil
    end

    def normalize_time_zone(value)
      return value if value.is_a?(ActiveSupport::TimeZone)

      Time.find_zone(value) || Time.zone
    end

    def local_day_start(date)
      time_zone.local(date.year, date.month, date.day).beginning_of_day
    end

    def local_day_end(date)
      time_zone.local(date.year, date.month, date.day).end_of_day
    end
  end
end
