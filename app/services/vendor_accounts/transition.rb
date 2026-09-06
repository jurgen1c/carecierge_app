module VendorAccounts
  class Transition
    ALLOWED = { "submitted" => %w[draft rejected], "approved" => %w[submitted],
      "rejected" => %w[submitted], "suspended" => %w[approved] }.freeze

    def self.call(...) = new(...).call

    def initialize(user:, account:, to:, version:, reason: nil)
      @user, @account, @to, @version, @reason = user, account, to, version, reason
    end

    def call
      policy = VendorAccountPolicy.new(@user, @account)
      raise Pundit::NotAuthorizedError unless @to == "submitted" ? policy.submit? : policy.moderate?
      @account.user.with_lock do
        @account.with_lock do
          @account.verify_version!(@version)
          from = @account.status
          unless ALLOWED.fetch(@to, []).include?(from)
            @account.errors.add(:base, :invalid_transition)
            raise ActiveRecord::RecordInvalid, @account
          end
          @account.update!(status: @to)
          publish_or_withdraw
          @account.record_transition!(from:, actor: @user, reason: @reason)
        end
      end
      @account
    end

    private

    def publish_or_withdraw
      if @to == "approved"
        listing = @account.marketplace_listing || @account.build_marketplace_listing
        listing.update!(name: @account.business_name, category: @account.categories.first,
          service_area: @account.service_area, curated_summary: @account.offerings,
          provider_details: [ @account.contact_channels, @account.provenance ].join("\n\n"),
          relationship_use_cases: @account.offerings, provider_name: @account.business_name,
          source_url: @account.source_url, reviewed_on: Date.current, published: true)
      else
        @account.marketplace_listing&.update!(published: false)
      end
    end
  end
end
