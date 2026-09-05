require "rails_helper"

# == Schema Information
#
# Table name: marketplace_listings
# Database name: primary
#
#  id                     :uuid             not null, primary key
#  category               :string           not null
#  curated_summary        :text             not null
#  name                   :string           not null
#  occasion_types         :string           default([]), not null, is an Array
#  provider_details       :text             not null
#  provider_name          :string           not null
#  published              :boolean          default(FALSE), not null
#  relationship_use_cases :text             not null
#  reviewed_on            :date             not null
#  service_area           :string           not null
#  source_url             :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_marketplace_listings_on_published_and_category  (published,category)
#
RSpec.describe MarketplaceListing, type: :model do
  it "requires bounded curated and sourced content" do
    listing = build(:marketplace_listing)
    expect(listing).to be_valid
    listing.assign_attributes(category: "unknown", occasion_types: [ "unknown" ], curated_summary: "x" * 2_001)
    expect(listing).not_to be_valid
    expect(listing.errors.attribute_names).to include(:category, :occasion_types, :curated_summary)
  end

  it "rejects unsafe source URLs and incomplete provenance" do
    [ "javascript:alert(1)", "https://user:pass@example.com", "//example.com" ].each do |url|
      expect(build(:marketplace_listing, source_url: url)).not_to be_valid
    end
    expect(build(:marketplace_listing, provider_name: nil)).not_to be_valid
    expect(build(:marketplace_listing, reviewed_on: nil)).not_to be_valid
  end
end
