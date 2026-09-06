module VendorAccounts
  class Enroll
    def self.call(user:)
      raise Pundit::NotAuthorizedError unless VendorAccountPolicy.new(user, VendorAccount).create?
      user.with_lock do
        raise Pundit::NotAuthorizedError unless user.confirmed?
        user.vendor_account || user.create_vendor_account!
      end
    end
  end
end
