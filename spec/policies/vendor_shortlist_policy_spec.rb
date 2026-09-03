require "rails_helper"

RSpec.describe VendorShortlistPolicy do
  it "permits owner reads and mutable writes" do
    shortlist = create(:vendor_shortlist)
    policy = described_class.new(shortlist.user, shortlist)

    expect(policy).to be_index
    expect(policy).to be_show
    expect(policy).to be_create
    expect(policy).to be_update
  end

  it "forbids foreign access and writes to completed plan shortlists" do
    shortlist = create(:vendor_shortlist)
    completed = create(:vendor_shortlist)
    completed.event_plan.complete!

    expect(described_class.new(create(:user), shortlist)).not_to be_show
    expect(described_class.new(completed.user, completed)).to be_show
    expect(described_class.new(completed.user, completed)).not_to be_update
  end

  it "scopes all shortlists to their owner, including archived relationships" do
    owned = create(:vendor_shortlist)
    archived = create(:vendor_shortlist, user: owned.user, relationship_profile: create(:relationship_profile, user: owned.user))
    archived.relationship_profile.discard!
    create(:vendor_shortlist)

    expect(described_class::Scope.new(owned.user, VendorShortlist).resolve).to contain_exactly(owned, archived)
  end

  it "authorizes option mutations only for the mutable shortlist owner" do
    option = create(:vendor_option)

    expect(VendorOptionPolicy.new(option.vendor_shortlist.user, option)).to be_update
    expect(VendorOptionPolicy.new(create(:user), option)).not_to be_update

    option.vendor_shortlist.event_plan.complete!
    expect(VendorOptionPolicy.new(option.vendor_shortlist.user, option.reload)).not_to be_update
    expect(VendorOptionPolicy.new(option.vendor_shortlist.user, option)).to be_destroy
    expect(VendorOptionPolicy.new(create(:user), option)).not_to be_destroy
  end
end
