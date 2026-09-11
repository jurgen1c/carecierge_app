module Concierge
  class Error < StandardError
    def code
      self.class.name.demodulize.underscore
    end
  end

  class RequestConflict < Error; end
  class ConversationBusy < Error; end
  class ContextUnavailable < Error; end
  class VaultLocked < Error; end
  class InvalidArguments < Error; end
  class ProviderUnavailable < Error; end
  class ExecutionExpired < Error; end
  class LimitReached < Error; end
  class PermissionDenied < Error; end
end
