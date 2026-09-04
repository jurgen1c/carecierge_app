module CalendarConnections
  class ConnectionError < StandardError
    attr_reader :code, :credentials, :previous_revocation_failed

    def initialize(message = "Calendar connection failed", code: "connection_failed", credentials: nil, previous_revocation_failed: false)
      @code = code
      @credentials = credentials
      @previous_revocation_failed = previous_revocation_failed
      super(message)
    end
  end
end
