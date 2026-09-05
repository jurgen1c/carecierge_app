require "net/http"

module Messaging
  class GoogleOauth
    Credentials = Data.define(:access_token, :refresh_token, :expires_at, :scopes)
    AUTHORIZATION_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
    TOKEN_ENDPOINT = URI("https://oauth2.googleapis.com/token")
    REVOKE_ENDPOINT = URI("https://oauth2.googleapis.com/revoke")
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    class << self
      def available?
        client_id.present? && client_secret.present? && ENV["GOOGLE_MESSAGING_ISOLATED_PROJECT"] == "true"
      end

      def authorization_url(state:, redirect_uri:)
        raise Error.new(code: "provider_unavailable") unless available?

        query = URI.encode_www_form(
          client_id:,
          redirect_uri:,
          response_type: "code",
          scope: MessagingConnection::GOOGLE_SCOPE,
          access_type: "offline",
          include_granted_scopes: "false",
          prompt: "consent",
          state:
        )
        "#{AUTHORIZATION_ENDPOINT}?#{query}"
      end

      def exchange(code:, redirect_uri:)
        token_request(
          code:,
          redirect_uri:,
          grant_type: "authorization_code"
        )
      end

      def refresh(refresh_token:)
        token_request(refresh_token:, grant_type: "refresh_token", existing_refresh_token: refresh_token)
      end

      def revoke(credentials:)
        token = credentials.refresh_token.presence || credentials.access_token
        request = Net::HTTP::Post.new(REVOKE_ENDPOINT)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(token:)
        response = perform(REVOKE_ENDPOINT, request)
        return true if response.is_a?(Net::HTTPSuccess) || response.code.to_i == 400

        code = transient_token_error_code(response) || "provider_rejected"
        raise Error.new(code:)
      rescue IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError,
        Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError
        raise Error.new(code: "provider_unavailable")
      end

      private

      def token_request(existing_refresh_token: nil, **parameters)
        partial_credentials = nil
        raise Error.new(code: "provider_unavailable") unless available?

        request = Net::HTTP::Post.new(TOKEN_ENDPOINT)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(parameters.merge(client_id:, client_secret:))
        response = perform(TOKEN_ENDPOINT, request)
        transient_code = transient_token_error_code(response)
        raise Error.new(code: transient_code) if transient_code

        payload = JSON.parse(response.body)
        raise Error.new(code: "invalid_provider_response") unless payload.is_a?(Hash)
        unless response.is_a?(Net::HTTPSuccess)
          raise Error.new(code: token_error_code(response, payload))
        end

        scopes = payload.fetch("scope", existing_refresh_token ? MessagingConnection::GOOGLE_SCOPE : "").to_s.split
        refresh_token = payload["refresh_token"].presence || existing_refresh_token
        partial_credentials = Credentials.new(
          access_token: payload["access_token"].presence,
          refresh_token:,
          expires_at: nil,
          scopes:
        )
        unless payload["access_token"].present? && refresh_token.present? && scopes == [ MessagingConnection::GOOGLE_SCOPE ]
          raise Error.new(code: "authorization_required", credentials: partial_credentials)
        end

        partial_credentials.with(
          expires_at: Time.current + Integer(payload.fetch("expires_in", 3600)),
        )
      rescue JSON::ParserError, KeyError, ArgumentError, TypeError
        raise Error.new(code: "invalid_provider_response", credentials: partial_credentials)
      rescue IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError,
        Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError
        raise Error.new(code: "provider_unavailable")
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

      def token_error_code(response, payload)
        payload["error"].to_s.presence || "token_exchange_failed"
      end

      def transient_token_error_code(response)
        status = response.code.to_i
        return "rate_limited" if status == 429
        "provider_unavailable" if status >= 500
      end

      def client_id = ENV["GOOGLE_MESSAGING_CLIENT_ID"]
      def client_secret = ENV["GOOGLE_MESSAGING_CLIENT_SECRET"]
    end
  end
end
