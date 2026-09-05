class AllowPartialCalendarCredentialRevocations < ActiveRecord::Migration[8.1]
  TOKEN_CHECK = "access_token IS NOT NULL OR refresh_token IS NOT NULL"
  ERROR_CODES_WITH_PERMISSION = <<~SQL.squish
    last_error_code IS NULL OR last_error_code IN (
      'authorization_required',
      'calendar_authorization_incomplete',
      'calendar_permission_required',
      'invalid_grant',
      'invalid_provider_response',
      'provider_error',
      'provider_rejected',
      'provider_unavailable',
      'rate_limited',
      'revocation_failed'
    )
  SQL
  ORIGINAL_ERROR_CODES = <<~SQL.squish
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

  def up
    change_column_null :calendar_credential_revocations, :access_token, true
    change_column_null :calendar_credential_revocations, :refresh_token, true
    add_check_constraint :calendar_credential_revocations,
      TOKEN_CHECK,
      name: "calendar_credential_revocations_have_a_token"

    remove_check_constraint :calendar_connections, name: "calendar_connections_supported_error_code"
    add_check_constraint :calendar_connections,
      ERROR_CODES_WITH_PERMISSION,
      name: "calendar_connections_supported_error_code"
  end

  def down
    remove_check_constraint :calendar_connections, name: "calendar_connections_supported_error_code"
    execute <<~SQL.squish
      UPDATE calendar_connections
      SET last_error_code = 'provider_error'
      WHERE last_error_code = 'calendar_permission_required'
    SQL
    add_check_constraint :calendar_connections,
      ORIGINAL_ERROR_CODES,
      name: "calendar_connections_supported_error_code"

    remove_check_constraint :calendar_credential_revocations,
      name: "calendar_credential_revocations_have_a_token"
    execute <<~SQL.squish
      UPDATE calendar_credential_revocations
      SET access_token = COALESCE(access_token, refresh_token),
          refresh_token = COALESCE(refresh_token, access_token)
    SQL
    change_column_null :calendar_credential_revocations, :access_token, false
    change_column_null :calendar_credential_revocations, :refresh_token, false
  end
end
