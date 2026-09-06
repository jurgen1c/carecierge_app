FactoryBot.define do
  factory :vendor_account do
    user
    business_name { "Orchid Studio" }
    categories { [ "florist" ] }
    service_area { "San José, Heredia" }
    offerings { "Seasonal bouquets for celebrations" }
    contact_channels { "Business phone: +506 2222 2222" }
    source_url { "https://orchid.example.com" }
    provenance { "Supplied by the business owner" }
  end
end
