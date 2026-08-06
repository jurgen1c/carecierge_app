require "rails_helper"

RSpec.describe AutomationPermissionPolicy do
  let(:owner) { create(:user) }
  let(:permission) { create(:automation_permission, user: owner) }

  it "allows authenticated users to manage their settings and owned permissions" do
    expect(described_class.new(owner, AutomationPermission).edit?).to be(true)
    expect(described_class.new(owner, AutomationPermission).update?).to be(true)
    expect(described_class.new(owner, permission).update?).to be(true)
    expect(described_class.new(owner, permission).destroy?).to be(true)
  end

  it "denies another user's permission and scopes it out" do
    other_user = create(:user)

    expect(described_class.new(other_user, permission).update?).to be(false)
    expect(described_class.new(other_user, permission).destroy?).to be(false)
    expect(described_class::Scope.new(other_user, AutomationPermission).resolve).to be_empty
  end

  it "denies unauthenticated access" do
    expect(described_class.new(nil, AutomationPermission).edit?).to be_falsey
    expect(described_class::Scope.new(nil, AutomationPermission).resolve).to be_empty
  end
end
