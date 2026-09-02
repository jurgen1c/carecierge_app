require "rails_helper"

RSpec.describe VendorShortlists::Create do
  it "creates a relationship shortlist with selected owner-scoped vendors" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    vendors = create_list(:vendor, 2, user:)

    shortlist = described_class.call(
      user:,
      attributes: { title: "Dinner options", relationship_profile: profile },
      vendors:
    )

    expect(shortlist).to be_persisted
    expect(shortlist.vendors).to contain_exactly(*vendors)
  end

  it "rejects foreign vendors atomically" do
    user = create(:user)
    profile = create(:relationship_profile, user:)

    expect do
      described_class.call(
        user:,
        attributes: { title: "Dinner options", relationship_profile: profile },
        vendors: [ create(:vendor) ]
      )
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(VendorShortlist.count).to eq(0)
  end

  it "re-resolves vendors inside the owner lock before creating options" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    stale_vendor = create(:vendor, user:)
    Vendor.where(id: stale_vendor.id).delete_all

    expect do
      described_class.call(
        user:,
        attributes: { title: "Dinner options", relationship_profile: profile },
        vendors: [ stale_vendor ]
      )
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(VendorShortlist.count).to eq(0)
  end

  it "revalidates a stale relationship under its lifecycle lock" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    attributes = { title: "Dinner options", relationship_profile: profile }
    RelationshipProfile.where(id: profile.id).update_all(discarded_at: Time.zone.local(2026, 9, 2, 9))

    expect do
      described_class.call(user:, attributes:, vendors: [])
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(VendorShortlist.count).to eq(0)
  end

  it "revalidates a stale event plan under its lifecycle lock" do
    plan = create(:event_plan)
    attributes = { title: "Dinner options", relationship_profile: plan.relationship_profile, event_plan: plan }
    EventPlan.where(id: plan.id).update_all(status: "completed", completed_at: Time.zone.local(2026, 9, 2, 9))

    expect do
      described_class.call(user: plan.user, attributes:, vendors: [])
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(VendorShortlist.count).to eq(0)
  end

  it "caps a shortlist at five options" do
    shortlist = create(:vendor_shortlist)
    create_list(:vendor_option, VendorShortlist::MAX_OPTIONS, vendor_shortlist: shortlist)

    expect do
      shortlist.add_vendor!(create(:vendor, user: shortlist.user))
    end.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "re-resolves a vendor inside the owner lock before adding it" do
    shortlist = create(:vendor_shortlist)
    stale_vendor = create(:vendor, user: shortlist.user)
    Vendor.where(id: stale_vendor.id).delete_all

    expect do
      shortlist.add_vendor!(stale_vendor)
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(shortlist.vendor_options).to be_empty
  end
end
