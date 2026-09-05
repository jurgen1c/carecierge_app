module MarketplaceListings
  class Save
    def self.call(user:, listing:)
      user.with_lock("FOR NO KEY UPDATE") do
        listing.with_lock do
          raise ActiveRecord::RecordNotFound unless listing.published?

          user.vendors.find_by(marketplace_listing: listing) || user.vendors.create!(listing.vendor_attributes)
        end
      end
    end
  end
end
