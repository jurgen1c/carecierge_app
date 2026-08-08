class AuditEventsController < ApplicationController
  FILTER_KEYS = %w[event_action source occurred_from occurred_to].freeze

  def index
    authorize AuditEvent
    @time_zone = Time.find_zone(current_user.notification_preference&.time_zone) || Time.zone
    @query = AuditEvents::Query.new(current_user.audit_events, filters: filter_params, time_zone: @time_zone)
    @pagy, @audit_events = pagy(:offset, @query.resolve, limit: 20)
    @grouped_audit_events = @audit_events.group_by { |event| event.occurred_at.in_time_zone(@time_zone).to_date }
    @today = Time.current.in_time_zone(@time_zone).to_date
    @yesterday = @today.yesterday
  end

  private

  def filter_params
    FILTER_KEYS.index_with { |key| params[key] }
  end
end
