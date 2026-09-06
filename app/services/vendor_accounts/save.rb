module VendorAccounts
  class Save
    def self.call(user:, account:, attributes:, version:)
      raise Pundit::NotAuthorizedError unless VendorAccountPolicy.new(user, account).update?
      user.with_lock do
        account.with_lock do
          account.verify_version!(version)
          from = account.status
          account.assign_attributes(attributes.slice(*VendorAccount::PROFILE_FIELDS.map(&:to_sym)))
          account.status = "draft" unless from == "suspended"
          account.save!
          account.marketplace_listing&.update!(published: false)
          account.record_transition!(from:, actor: user) if from != account.status
        end
      end
      account
    end
  end
end
