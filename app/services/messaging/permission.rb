module Messaging
  class Permission
    def self.check!(user:, capability: "access_messages")
      allowed = AutomationPermission.decision_for(user:, capability:).permits_execution?(explicitly_approved: true)
      raise Error.new(code: "permission_required") unless allowed
    end
  end
end
