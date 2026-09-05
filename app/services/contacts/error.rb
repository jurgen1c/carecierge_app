module Contacts
  class Error < StandardError
    attr_reader :code, :credentials
    def initialize(message = "Contacts operation failed", code: "failed", credentials: nil)
      @code, @credentials = code, credentials
      super(message)
    end
  end
end
