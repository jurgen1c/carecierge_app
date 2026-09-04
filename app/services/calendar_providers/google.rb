require "net/http"

module CalendarProviders
  class Google
    EVENTS_ENDPOINT = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    REVOKE_ENDPOINT = URI("https://oauth2.googleapis.com/revoke")
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    QUOTA_ERROR_REASONS = %w[dailyLimitExceeded quotaExceeded rateLimitExceeded userRateLimitExceeded].freeze

    def initialize(connection:)
      @connection = connection
      @expected_sync_lease_token = connection.sync_lease_token
    end

    def create_event(attributes, event_id:)
      response = request(:post, events_uri, attributes: attributes.merge(id: event_id), allow_conflict: true)
      if response.code.to_i == 409
        update_event(event_id, attributes)
        return event_id
      end

      payload = JSON.parse(response.body)
      payload.fetch("id")
    rescue JSON::ParserError, KeyError
      raise PermanentError.new(code: "invalid_provider_response")
    end

    def update_event(external_event_id, attributes)
      request_json(:put, event_uri(external_event_id), attributes)
      true
    end

    def delete_event(external_event_id)
      request(:delete, event_uri(external_event_id), allow_not_found: true)
      true
    end

    def revoke
      token = connection.refresh_token.presence || connection.access_token
      request = Net::HTTP::Post.new(REVOKE_ENDPOINT)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request.body = URI.encode_www_form(token:)
      response = perform(REVOKE_ENDPOINT, request)
      return true if response.is_a?(Net::HTTPSuccess) || response.code.to_i == 400

      classify_response!(response)
    rescue IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError
      raise TransientError.new(code: "provider_unavailable")
    end

    private

    attr_reader :connection, :expected_sync_lease_token

    def events_uri
      URI("#{EVENTS_ENDPOINT}?sendUpdates=none")
    end

    def event_uri(external_event_id)
      escaped_id = URI.encode_www_form_component(external_event_id)
      URI("#{EVENTS_ENDPOINT}/#{escaped_id}?sendUpdates=none")
    end

    def request_json(method, uri, attributes)
      response = request(method, uri, attributes:)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise PermanentError.new(code: "invalid_provider_response")
    end

    def request(method, uri, attributes: nil, allow_not_found: false, allow_conflict: false)
      request_class = { post: Net::HTTP::Post, put: Net::HTTP::Put, delete: Net::HTTP::Delete }.fetch(method)
      http_request = request_class.new(uri)
      http_request["Authorization"] = "Bearer #{current_access_token}"
      if attributes
        http_request["Content-Type"] = "application/json"
        http_request.body = JSON.generate(attributes.deep_transform_keys { |key| key.to_s.camelize(:lower) })
      end
      response = perform(uri, http_request)
      return response if response.is_a?(Net::HTTPSuccess) || allow_not_found && response.code.to_i.in?([ 404, 410 ]) ||
        allow_conflict && response.code.to_i == 409

      classify_response!(response)
    rescue IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError
      raise TransientError.new(code: "provider_unavailable")
    end

    def current_access_token
      return connection.access_token if connection.token_expires_at > 1.minute.from_now

      credentials = CalendarConnections::GoogleOauth.refresh(refresh_token: connection.refresh_token)
      connection.with_lock do
        if expected_sync_lease_token &&
            (connection.sync_lease_token != expected_sync_lease_token || connection.sync_lease_expires_at&.past?)
          raise LeaseLostError.new(code: "provider_error")
        end

        connection.update!(
          access_token: credentials.access_token,
          refresh_token: credentials.refresh_token,
          token_expires_at: credentials.expires_at,
          granted_scopes: credentials.scopes
        )
      end
      credentials.access_token
    rescue CalendarConnections::ConnectionError => error
      error_class = error.code.in?(CalendarConnection::RETRYABLE_ERROR_CODES) ? TransientError : AuthorizationError
      raise error_class.new(code: error.code)
    end

    def classify_response!(response)
      status = response.code.to_i
      raise NotFoundError.new(code: "provider_event_missing") if status.in?([ 404, 410 ])
      raise AuthorizationError.new(code: "authorization_required") if status == 401
      raise TransientError.new(code: "rate_limited") if status == 403 && quota_response?(response)
      raise AuthorizationError.new(code: "authorization_required") if status == 403
      raise TransientError.new(code: status == 429 ? "rate_limited" : "provider_unavailable") if status == 429 || status >= 500

      raise PermanentError.new(code: "provider_rejected")
    end

    def quota_response?(response)
      errors = JSON.parse(response.body).dig("error", "errors")
      Array(errors).any? { |error| error.is_a?(Hash) && error["reason"].in?(QUOTA_ERROR_REASONS) }
    rescue JSON::ParserError, TypeError
      false
    end

    def perform(uri, request)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) { |http| http.request(request) }
    end
  end
end
