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
FactoryBot.define do
  factory :marketplace_listing do
    name { "Bloom & Stem" }
    category { "florist" }
    service_area { "San José" }
    occasion_types { [ "birthday", "anniversary" ] }
    relationship_use_cases { "A thoughtful thank-you or celebration" }
    curated_summary { "Consider a seasonal arrangement after checking preferences." }
    provider_name { "Vendor website" }
    provider_details { "Delivery available by arrangement; confirm directly." }
    source_url { "https://example.com/flowers" }
    reviewed_on { Date.new(2026, 9, 1) }
    published { true }
  end
end
