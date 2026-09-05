require "net/http"

module Contacts
  class Google
    ENDPOINT = "https://people.googleapis.com/v1/people/me/connections"
    def initialize(connection:)
      @connection = connection
    end

    def page(page_token: nil)
      refresh_token!
      uri = URI(ENDPOINT)
      uri.query = URI.encode_www_form({ personFields: "names,emailAddresses,phoneNumbers,birthdays", pageSize: 100,
        sortOrder: "FIRST_NAME_ASCENDING", sources: "READ_SOURCE_TYPE_CONTACT", pageToken: page_token }.compact)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{connection.access_token}"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.request(request) }
      raise Error.new(code: "authorization_required") if response.code.to_i == 401 || response.code.to_i == 403 && authorization_failure?(response.body)
      raise Error.new(code: "provider_unavailable") unless response.is_a?(Net::HTTPSuccess)
      payload = JSON.parse(response.body)
      rows = payload.fetch("connections", [])
      raise Error.new(code: "invalid_provider_response") unless rows.is_a?(Array) && rows.size <= 100
      { contacts: rows.map { |row| normalize(row) }, next_page_token: payload["nextPageToken"].presence }
    rescue JSON::ParserError, KeyError, TypeError, ArgumentError
      raise Error.new(code: "invalid_provider_response")
    rescue IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError
      raise Error.new(code: "provider_unavailable")
    end

    private

    attr_reader :connection

    def authorization_failure?(body)
      payload = JSON.parse(body)
      error = payload.is_a?(Hash) && payload["error"].is_a?(Hash) ? payload["error"] : {}
      reasons = (Array(error["errors"]) + Array(error["details"])).filter_map { |detail| detail["reason"] if detail.is_a?(Hash) }
      (reasons & %w[authError insufficientPermissions ACCESS_TOKEN_SCOPE_INSUFFICIENT CREDENTIALS_MISSING]).any?
    rescue JSON::ParserError
      false
    end

    def refresh_token!
      return if connection.token_expires_at && connection.token_expires_at > 1.minute.from_now
      credentials = GoogleOauth.refresh(refresh_token: connection.refresh_token)
      connection.update!(access_token: credentials.access_token, refresh_token: credentials.refresh_token, token_expires_at: credentials.expires_at)
    end

    def normalize(row)
      name = Array(row["names"]).first || {}
      date = Array(row["birthdays"]).filter_map { |birthday| birthday["date"] }.first || {}
      birthday = if date["year"].to_i.positive? && Date.valid_date?(date["year"].to_i, date["month"].to_i, date["day"].to_i)
        Date.new(date["year"].to_i, date["month"].to_i, date["day"].to_i).iso8601
      end
      { "external_id" => row.fetch("resourceName"), "first_name" => (name["givenName"].presence || name["displayName"]).to_s.truncate(200),
        "last_name" => name["givenName"].present? ? name["familyName"].to_s.truncate(200).presence : nil,
        "email" => Array(row["emailAddresses"]).first&.fetch("value", nil).to_s.truncate(320).presence,
        "phone" => Array(row["phoneNumbers"]).first&.fetch("value", nil).to_s.truncate(80).presence,
        "birthday" => birthday }
    end
  end
end
