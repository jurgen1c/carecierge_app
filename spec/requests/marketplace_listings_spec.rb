require "rails_helper"

RSpec.describe "Marketplace listings", type: :request do
  let(:user) { create(:user) }
  let!(:listing) { create(:marketplace_listing) }

  before { sign_in user }

  it "browses published listings and separates curated advice from provider claims" do
    create(:marketplace_listing, name: "Hidden supplier", published: false)
    get marketplace_listings_path
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML5(response.body).text).to include(listing.name, "Carecierge curation", "Provider details", listing.provider_details)
    expect(response.body).not_to include("Hidden supplier")
  end

  it "searches vendor names and filters by service area, category, and use case" do
    create(:marketplace_listing, name: "Another option", category: "restaurant", service_area: "Heredia")
    get marketplace_listings_path, params: { q: { name_or_curated_summary_cont: "Bloom", service_area_cont: "San", category_eq: "florist" }, occasion: "birthday" }
    expect(Nokogiri::HTML5(response.body).text).to include(listing.name)
    expect(response.body).not_to include("Another option")
  end

  it "compares selected listings and rejects oversized or unpublished selections" do
    other = create(:marketplace_listing, name: "Garden flowers")
    get compare_marketplace_listings_path, params: { listing_ids: [ listing.id, other.id ] }
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML5(response.body).text).to include(listing.name, other.name, "Compare marketplace options")
    get compare_marketplace_listings_path, params: { listing_ids: Array.new(6) { SecureRandom.uuid } }
    expect(response).to have_http_status(:unprocessable_content)
    hidden = create(:marketplace_listing, published: false)
    get compare_marketplace_listings_path, params: { listing_ids: [ hidden.id ] }
    expect(response).to have_http_status(:not_found)
  end

  it "saves an immutable private snapshot idempotently without accepting forged content" do
    expect do
      2.times { post save_marketplace_listing_path(listing), params: { vendor: { name: "Forged", user_id: create(:user).id } } }
    end.to change(user.vendors, :count).by(1)
    saved = user.vendors.sole
    expect(saved).to have_attributes(name: listing.name, source_kind: "external", source_name: listing.provider_name, marketplace_listing_id: listing.id)
    listing.update!(name: "Changed catalog name")
    expect(saved.reload.name).to eq("Bloom & Stem")
    expect(response).to redirect_to(marketplace_listing_path(listing))
  end

  it "keeps saves private and shows only the current owner's handoffs" do
    create(:event_plan, user:)
    foreign = create(:vendor, marketplace_listing: listing)
    get marketplace_listing_path(listing)
    expect(response.body).not_to include(foreign.id)
    expect(response.body).to include("Save to my vendors")
    post save_marketplace_listing_path(listing)
    get marketplace_listing_path(listing)
    expect(response.body).to include("Use this saved choice", "Gift idea", "Booking draft", "Shortlist")
  end

  it "does not expose or save withdrawn listings" do
    listing.update!(published: false)
    get marketplace_listing_path(listing)
    expect(response).to have_http_status(:not_found)
    expect { post save_marketplace_listing_path(listing) }.not_to change(Vendor, :count)
    expect(response).to have_http_status(:not_found)
  end

  it "renders Spanish catalog, detail and comparison without missing translations" do
    I18n.with_locale(:es) do
      [ marketplace_listings_path, marketplace_listing_path(listing), compare_marketplace_listings_path(listing_ids: [ listing.id ]) ].each do |path|
        get path
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Translation missing")
      end
    end
  end

  it "opens owned planning and gift/booking drafts without creating records" do
    plan = create(:event_plan, user:)
    post save_marketplace_listing_path(listing)
    vendor = user.vendors.sole

    get use_marketplace_listing_path(listing), params: { destination: "plan", event_plan_id: plan.id }
    expect(response).to redirect_to(vendors_path(event_plan_id: plan.id, vendor_id: vendor.id))
    expect(plan.vendors).to be_empty

    get use_marketplace_listing_path(listing), params: { destination: "booking", event_plan_id: plan.id }
    expect(response).to redirect_to(new_event_plan_booking_path(plan, vendor_id: vendor.id))
    expect { follow_redirect! }.not_to change(Booking, :count)
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML5(response.body).at_css("input[name='booking[provider_name]']")["value"]).to eq(vendor.name)

    get use_marketplace_listing_path(listing), params: { destination: "gift", relationship_profile_id: plan.relationship_profile_id }
    expect(response).to redirect_to(new_relationship_profile_gift_path(plan.relationship_profile, vendor_id: vendor.id))
    expect { follow_redirect! }.not_to change(Gift, :count)
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML5(response.body).at_css("input[name='gift[vendor]']")["value"]).to eq(vendor.name)

    get use_marketplace_listing_path(listing), params: { destination: "shortlist" }
    expect(response).to redirect_to(new_vendor_shortlist_path(vendor_ids: [ vendor.id ]))
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML5(response.body).at_css("input[value='#{vendor.id}']")["checked"]).to eq("checked")
  end

  it "rejects foreign or inactive contexts and private vendor IDs at every draft boundary" do
    plan = create(:event_plan, user:)
    foreign_plan = create(:event_plan)
    vendor = create(:vendor)
    post save_marketplace_listing_path(listing)
    %w[plan booking].each do |destination|
      get use_marketplace_listing_path(listing), params: { destination:, event_plan_id: foreign_plan.id }
      expect(response).to have_http_status(:not_found)
    end
    get use_marketplace_listing_path(listing), params: { destination: "gift", relationship_profile_id: foreign_plan.relationship_profile_id }
    expect(response).to have_http_status(:not_found)
    get new_event_plan_booking_path(plan), params: { vendor_id: vendor.id }
    expect(response).to have_http_status(:not_found)
    get new_relationship_profile_gift_path(plan.relationship_profile), params: { vendor_id: vendor.id }
    expect(response).to have_http_status(:not_found)
    get new_vendor_shortlist_path, params: { vendor_ids: [ vendor.id ] }
    expect(response).to have_http_status(:not_found)
    plan.update!(status: "completed")
    get use_marketplace_listing_path(listing), params: { destination: "booking", event_plan_id: plan.id }
    expect(response).to have_http_status(:not_found)
  end

  it "retains the selected vendor despite mismatching plan defaults" do
    plan = create(:event_plan, user:, occasion_type: "birthday", budget_cents: 100)
    listing.update!(occasion_types: [ "anniversary" ])
    post save_marketplace_listing_path(listing)
    user.vendors.sole.update!(minimum_price_cents: 10_000)
    get use_marketplace_listing_path(listing), params: { destination: "plan", event_plan_id: plan.id }
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML5(response.body).text).to include(listing.name)
    expect(response.body).to include(event_plan_vendors_path(plan))
  end

  it "requires a private save before offering any handoff" do
    get use_marketplace_listing_path(listing), params: { destination: "shortlist" }
    expect(response).to have_http_status(:not_found)
  end

  it "retains checked options with localized comparison validation feedback" do
    listings = create_list(:marketplace_listing, 6)
    I18n.with_locale(:es) do
      get compare_marketplace_listings_path, params: { listing_ids: listings.map(&:id) }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Elige de una a cinco opciones para comparar.")
      expect(Nokogiri::HTML5(response.body).css("input[name='listing_ids[]'][checked]").count).to eq(6)
    end
    get new_vendor_shortlist_path, params: { vendor_ids: Array.new(6) { SecureRandom.uuid } }
    expect(response).to have_http_status(:bad_request)
  end

  it "requires authentication" do
    sign_out user
    get marketplace_listings_path
    expect(response).to redirect_to(new_user_session_path)
  end
end
