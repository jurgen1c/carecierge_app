require "net/http"

module Messaging
  class Google
    ENDPOINT = "https://gmail.googleapis.com/gmail/v1/users/me/messages"
    MAX_RESULTS = 10
    def initialize(connection:)
      @connection = connection
    end

    def mailbox_email
      row = get(URI("https://gmail.googleapis.com/gmail/v1/users/me/profile"), fields: "emailAddress")
      value = row["emailAddress"]
      unless value.is_a?(String) && value.length <= 320 && value.match?(URI::MailTo::EMAIL_REGEXP)
        raise Error.new(code: "invalid_provider_response")
      end
      value
    end

    def search(query:)
      raise Error.new(code: "invalid_query") unless query.is_a?(String) && query.strip.present? && query.length <= 300
      payload = get(URI(ENDPOINT), q: query, maxResults: MAX_RESULTS, fields: "messages(id)")
      rows = payload.fetch("messages", [])
      raise Error.new(code: "invalid_provider_response") unless rows.is_a?(Array) && rows.size <= MAX_RESULTS
      rows.map { |row| message(external_id: row.fetch("id")) }
    rescue KeyError, TypeError
      raise Error.new(code: "invalid_provider_response")
    end

    def message(external_id:)
      raise Error.new(code: "invalid_source") unless external_id.is_a?(String) && external_id.match?(/\A[0-9a-f]{1,64}\z/i)
      row = get(URI("#{ENDPOINT}/#{external_id}"), format: "full", fields: "id,threadId,snippet,payload(headers)")
      headers = row.dig("payload", "headers") || []
      raise Error.new(code: "invalid_provider_response") unless headers.is_a?(Array)
      subject = headers.find { |header| header["name"].to_s.casecmp?("Subject") }&.fetch("value", "")
      id, thread = row.fetch("id"), row.fetch("threadId")
      unless id == external_id && thread.is_a?(String) && thread.match?(/\A[0-9a-f]{1,64}\z/i)
        raise Error.new(code: "invalid_provider_response")
      end
      { external_id: id, thread_id: thread, subject: subject.to_s.truncate(500), snippet: CGI.unescapeHTML(row.fetch("snippet").to_s).truncate(2_000) }
    rescue KeyError, TypeError, NoMethodError
      raise Error.new(code: "invalid_provider_response")
    end

    private

    attr_reader :connection

    def get(uri, **params)
      refresh_token!
      uri.query = URI.encode_www_form(params)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{connection.access_token}"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.request(request) }
      raise Error.new(code: "authorization_required") if [ 401, 403 ].include?(response.code.to_i)
      raise Error.new(code: "provider_unavailable") unless response.is_a?(Net::HTTPSuccess)
      payload = JSON.parse(response.body)
      raise Error.new(code: "invalid_provider_response") unless payload.is_a?(Hash)
      payload
    rescue JSON::ParserError
      raise Error.new(code: "invalid_provider_response")
    rescue IOError, SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError
      raise Error.new(code: "provider_unavailable")
    end

    def refresh_token!
      return if connection.token_expires_at && connection.token_expires_at > 1.minute.from_now
      credentials = GoogleOauth.refresh(refresh_token: connection.refresh_token)
      connection.update!(access_token: credentials.access_token, refresh_token: credentials.refresh_token, token_expires_at: credentials.expires_at)
    end
  end
end
