require "rails_helper"

RSpec.describe VendorAccount, type: :model do
  it "bounds draft content and rejects unsafe sources and unsupported categories" do
    account = build(:vendor_account)
    { business_name: "x" * 201, service_area: "x" * 201, offerings: "x" * 2001,
      contact_channels: "x" * 951, provenance: "x" * 951, source_url: "javascript:alert(1)",
      categories: Vendor::CATEGORIES.first(6) }.each do |field, value|
      account = build(:vendor_account, field => value)
      expect(account).not_to be_valid
      expect(account.errors[field]).to be_present
    end
    expect(build(:vendor_account, source_url: "https://secret:password@example.com")).not_to be_valid
    expect(build(:vendor_account, categories: [ "florist", "florist" ])).not_to be_valid
    expect(build(:vendor_account, categories: [ "unknown" ])).not_to be_valid
  end

  it "exports the owner's business and decrypted review evidence only in account exports" do
    account = create(:vendor_account)
    VendorAccounts::Transition.call(user: account.user, account:, to: "submitted", version: "0")
    exported = DataExports::Snapshot.new(user: account.user).to_h.fetch("vendor_account")
    expect(exported["business_name"]).to eq(account.business_name)
    expect(exported["reviews"].sole["profile_snapshot"]["offerings"]).to eq(account.offerings)
    expect(exported["reviews"].sole).not_to have_key("actor_id")
    expect(DataExports::Snapshot.new(user: create(:user)).to_h["vendor_account"]).to be_nil
    profile = create(:relationship_profile, user: account.user)
    expect(DataExports::Snapshot.new(user: account.user, relationship_profile: profile).to_h).not_to have_key("vendor_account")
  end

  it "deletes account-owned publication and evidence without deleting consumers' saved vendors" do
    account = create(:vendor_account)
    moderator = create(:user, admin: true)
    VendorAccounts::Transition.call(user: account.user, account:, to: "submitted", version: "0")
    VendorAccounts::Transition.call(user: moderator, account:, to: "approved", version: account.lock_version.to_s)
    listing = account.reload.marketplace_listing
    consumer = create(:user)
    saved = MarketplaceListings::Save.call(user: consumer, listing:)
    account.user.destroy!
    expect(VendorAccount.exists?(account.id)).to be(false)
    expect(MarketplaceListing.exists?(listing.id)).to be(false)
    expect(VendorAccountReview.where(vendor_account_id: account.id)).to be_empty
    expect(consumer.vendors.sole.reload.marketplace_listing_id).to be_nil
  end

  it "filters entire onboarding and moderation payloads" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    expect(filter.filter("vendor_account" => { "contact_channels" => "secret" },
      "moderation" => { "reason" => "private review" })).to eq("vendor_account" => "[FILTERED]", "moderation" => "[FILTERED]")
  end
end
