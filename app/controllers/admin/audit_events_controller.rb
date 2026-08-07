module Admin
  class AuditEventsController < ApplicationController
    FILTER_KEYS = %w[account event_action source occurred_from occurred_to].freeze

    def index
      authorize AuditEvent, :admin_index?
      @account_filter = display_account_filter
      @query = AuditEvents::Query.new(policy_scope(AuditEvent), filters: audit_filters)
      @pagy, @audit_events = pagy(:offset, @query.resolve, limit: 20)
    end

    private

    def filter_params
      @filter_params ||= FILTER_KEYS.index_with { |key| params[key] }
    end

    def audit_filters
      filters = filter_params.except("account")
      filters["user_id"] = account_user_id if account_filter_submitted?
      filters
    end

    def account_user_id
      return "invalid" unless filter_params["account"].is_a?(String)

      return @account_filter if @account_filter.match?(AuditEvents::Query::UUID_PATTERN)

      User.find_by(email: @account_filter.downcase)&.id || "invalid"
    end

    def account_filter_submitted?
      value = filter_params["account"]
      value.is_a?(String) ? value.strip.present? : !value.nil?
    end

    def display_account_filter
      value = filter_params["account"]
      value.is_a?(String) ? value.strip : ""
    end
  end
end
