require "rails_helper"

RSpec.describe VaultAccessEvent, type: :model do
  it "records a generic privacy-minimized audit event with each specialized event" do
    user = create(:user)
    profile = create(:relationship_profile, user:)

    event = described_class.record!(event_type: "unlocked", user:, relationship_profile: profile)

    expect(event).to be_a(described_class)
    expect(user.audit_events.sole).to have_attributes(
      actor: user,
      action: "privacy_vault.opened",
      source: "web_app",
      target_id: profile.id,
      target_type: "RelationshipProfile",
      metadata: {}
    )
  end

  it "rolls back the specialized event when the generic event fails" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid.new(AuditEvent.new))

    expect do
      described_class.record!(event_type: "protected", user:, relationship_profile: profile)
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(described_class.count).to eq(0)
  end

  it "keeps a durable relationship target when the audited vault item is deleted" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    item = create(:privacy_vault_item, relationship_profile: profile)

    described_class.record!(
      event_type: "restored",
      user:,
      relationship_profile: profile,
      privacy_vault_item: item
    )
    item.destroy!

    expect(user.audit_events.sole.reload).to have_attributes(
      action: "privacy_vault.restored",
      target_id: profile.id,
      target_type: "RelationshipProfile"
    )
  end

  it "keeps access-only event recording best effort when either audit insert fails" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    error = ActiveRecord::RecordInvalid.new(AuditEvent.new)
    allow(AuditEvent).to receive(:record!).and_raise(error)
    allow(Rails.error).to receive(:report)

    expect(described_class.record_safely(event_type: "viewed", user:, relationship_profile: profile)).to be_nil
    expect(described_class.count).to eq(0)
    expect(Rails.error).to have_received(:report).with(
      error,
      handled: true,
      context: { component: "privacy_vault_access_audit", event_type: "viewed" }
    )
  end

  describe ".record_safely" do
    it "reports persistence failures without exposing record attributes" do
      error = ActiveRecord::RecordInvalid.new(described_class.new)
      allow(described_class).to receive(:record!).and_raise(error)
      allow(Rails.error).to receive(:report)

      result = described_class.record_safely(
        event_type: "viewed",
        user: build(:user),
        relationship_profile: build(:relationship_profile)
      )

      expect(result).to be_nil
      expect(Rails.error).to have_received(:report).with(
        error,
        handled: true,
        context: { component: "privacy_vault_access_audit", event_type: "viewed" }
      )
    end
  end
end
