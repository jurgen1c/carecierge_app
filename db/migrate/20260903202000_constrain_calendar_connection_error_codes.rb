class ConstrainCalendarConnectionErrorCodes < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :calendar_connections,
      <<~SQL.squish,
        last_error_code IS NULL OR last_error_code IN (
          'authorization_required',
          'calendar_authorization_incomplete',
          'invalid_grant',
          'invalid_provider_response',
          'provider_error',
          'provider_rejected',
          'provider_unavailable',
          'rate_limited',
          'revocation_failed'
        )
      SQL
      name: "calendar_connections_supported_error_code"
  end
end
