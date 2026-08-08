require "rails_helper"

RSpec.describe AuditEvents::Track do
  let(:user) { create(:user) }
  let(:profile) { create(:relationship_profile, user:, first_name: "Before") }

  it "commits a mutation and its audit event together" do
    result = described_class.call(
      user:,
      actor: user,
      action: "relationship_profile.updated",
      target: profile,
      metadata: { changed_fields: "profile_details" }
    ) do
      profile.update!(first_name: "After")
      profile
    end

    expect(result).to eq(profile)
    expect(profile.reload.first_name).to eq("After")
    expect(user.audit_events.sole).to have_attributes(
      actor: user,
      action: "relationship_profile.updated",
      target_id: profile.id,
      target_type: "RelationshipProfile",
      metadata: { "changed_fields" => "profile_details" }
    )
  end

  it "rolls the mutation back when the audit event cannot be recorded" do
    allow(AuditEvent).to receive(:record!).and_raise(ActiveRecord::RecordInvalid.new(AuditEvent.new))

    expect do
      described_class.call(user:, actor: user, action: "relationship_profile.updated", target: profile) do
        profile.update!(first_name: "After")
      end
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(profile.reload.first_name).to eq("Before")
  end

  it "does not record an event when a non-bang mutation returns false" do
    result = described_class.call(user:, actor: user, action: "relationship_profile.updated", target: profile) { false }

    expect(result).to be(false)
    expect(AuditEvent.count).to eq(0)
  end

  it "commits a successful mutation without an event when the caller identifies a no-op" do
    result = described_class.call(
      user:,
      actor: user,
      action: "relationship_profile.updated",
      target: profile,
      record_if: false
    ) { profile.save }

    expect(result).to be(true)
    expect(AuditEvent.count).to eq(0)
  end
end
