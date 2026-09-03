module Vendors
  class Destroy
    def self.call(vendor:) = new(vendor:).call

    def initialize(vendor:)
      @vendor = vendor
    end

    def call
      vendor.user.with_lock("FOR NO KEY UPDATE") do
        vendor.lock!
        reject_comparison_use!

        begin
          vendor.transaction(requires_new: true) { vendor.destroy! }
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
          reject_comparison_use!
          raise
        end
      end
    end

    private

    attr_reader :vendor

    def reject_comparison_use!
      return unless vendor.vendor_options.exists?

      vendor.errors.add(:base, :used_in_comparisons)
      raise ActiveRecord::RecordInvalid, vendor
    end
  end
end
