require "rails_helper"

RSpec.describe MarketplaceListings::Save do
  it "rechecks withdrawal inside the lock and leaves private saves unchanged" do
    listing = create(:marketplace_listing)
    stale = MarketplaceListing.find(listing.id)
    listing.update!(published: false)
    expect { described_class.call(user: create(:user), listing: stale) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "preserves private saved details when a listing is deleted" do
    user = create(:user)
    listing = create(:marketplace_listing)
    vendor = described_class.call(user:, listing:)
    listing.destroy!
    expect(vendor.reload).to have_attributes(name: "Bloom & Stem", marketplace_listing_id: nil, source_url: "https://example.com/flowers")
  end
end
