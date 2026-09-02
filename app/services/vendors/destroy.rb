module Vendors
  class Destroy
    def self.call(vendor:) = new(vendor:).call

    def initialize(vendor:)
      @vendor = vendor
    end

    def call
      vendor.user.with_lock("FOR NO KEY UPDATE") do
        vendor.lock!
        if vendor.vendor_options.exists?
          vendor.errors.add(:base, :used_in_comparisons)
          raise ActiveRecord::RecordInvalid, vendor
        end

        vendor.destroy!
      end
    end

    private

    attr_reader :vendor
  end
end
