require "rails_helper"

RSpec.describe AuditEventPolicy do
  subject(:policy) { described_class.new(user, AuditEvent) }

  let!(:event) { create(:audit_event) }

  context "with an admin user" do
    let(:user) { create(:user, :admin) }

    it "allows the account history and admin ledger and resolves every event" do
      expect(policy.index?).to be(true)
      expect(policy.admin_index?).to be(true)
      expect(described_class::Scope.new(user, AuditEvent).resolve).to contain_exactly(event)
    end
  end

  context "with a non-admin user" do
    let(:user) { create(:user) }

    it "allows account history, denies the admin ledger, and resolves no cross-account events" do
      expect(policy.index?).to be(true)
      expect(policy.admin_index?).to be(false)
      expect(described_class::Scope.new(user, AuditEvent).resolve).to be_empty
    end
  end

  context "without a user" do
    let(:user) { nil }

    it "denies both views and resolves no events" do
      expect(policy.index?).to be_falsey
      expect(policy.admin_index?).to be_falsey
      expect(described_class::Scope.new(user, AuditEvent).resolve).to be_empty
    end
  end
end
