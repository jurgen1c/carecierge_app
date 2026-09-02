require "rails_helper"

RSpec.describe VendorPolicy do
  subject(:policy) { described_class.new(user, vendor) }

  let(:vendor) { create(:vendor) }

  context "when the vendor belongs to the user" do
    let(:user) { vendor.user }

    it "permits owner actions" do
      expect(%i[show create update destroy]).to all(satisfy { |action| policy.public_send("#{action}?") })
    end
  end

  context "when the vendor belongs to another user" do
    let(:user) { create(:user) }

    it "forbids foreign actions" do
      expect(%i[show create update destroy]).to all(satisfy { |action| !policy.public_send("#{action}?") })
    end
  end

  it "scopes vendors to their owner" do
    owned = create(:vendor)
    create(:vendor)

    expect(described_class::Scope.new(owned.user, Vendor).resolve).to contain_exactly(owned)
  end
end
