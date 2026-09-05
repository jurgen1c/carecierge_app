module Contacts
  class Permission
    def self.check!(user:, profile: nil)
      allowed = AutomationPermission.decision_for(user:, capability: "access_contacts", relationship_profile: profile)
        .permits_execution?(explicitly_approved: true)
      raise Error.new(code: "permission_required") unless allowed
    end
  end
end
