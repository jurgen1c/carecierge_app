module CalendarProviders
  class Error < StandardError
    attr_reader :code

    def initialize(message = "Calendar provider request failed", code: "provider_error")
      @code = code
      super(message)
    end
  end
end
