module Vendors
  class Destroy
    def self.call(vendor:) = new(vendor:).call

    def initialize(vendor:)
      @vendor = vendor
    end

    def call
      vendor.user.with_lock("FOR NO KEY UPDATE") do
        vendor.lock!
        vendor.destroy!
      end
    end

    private

    attr_reader :vendor
  end
end
