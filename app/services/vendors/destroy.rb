module Vendors
  class Destroy
    def self.call(vendor:) = new(vendor:).call

    def initialize(vendor:)
      @vendor = vendor
    end

    def call
      vendor.user.with_lock("FOR NO KEY UPDATE") do
        vendor.lock!
        reject_reference_use!

        begin
          vendor.transaction(requires_new: true) { vendor.destroy! }
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
          reject_reference_use!
          raise
        end
      end
    end

    private

    attr_reader :vendor

    def reject_reference_use!
      return unless vendor.vendor_options.exists? || vendor.vendor_quotes.exists?

      vendor.errors.add(:base, :used_in_quotes_or_comparisons)
      raise ActiveRecord::RecordInvalid, vendor
    end
  end
end
