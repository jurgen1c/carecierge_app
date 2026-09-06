require "rails_helper"

RSpec.describe VendorAccountPolicy, type: :policy do
  it "separates owner access from moderation and other owners" do
    account = create(:vendor_account)
    stranger = create(:user)
    admin = create(:user, admin: true)
    expect(described_class.new(account.user, account).update?).to be(true)
    expect(described_class.new(account.user, account).moderate?).to be(false)
    expect(described_class.new(stranger, account).show?).to be(false)
    expect(described_class.new(admin, account).show?).to be(false)
    expect(described_class.new(admin, account).moderate?).to be(true)
    expect(described_class.new(nil, account).create?).to be(false)
    expect(described_class::Scope.new(stranger, VendorAccount).resolve).to be_empty
    expect(described_class::Scope.new(nil, VendorAccount).resolve).to be_empty
  end
end
