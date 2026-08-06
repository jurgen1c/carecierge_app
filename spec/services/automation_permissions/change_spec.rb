require "rails_helper"

RSpec.describe AutomationPermissions::Change do
  let(:user) { create(:user) }

  it "writes an account permission and its audit event atomically" do
    permission = described_class.call(
      user:,
      actor: user,
      capability: :draft_messages,
      mode: "ask_every_time"
    )

    expect(permission).to have_attributes(
      user:,
      relationship_profile: nil,
      capability: "draft_messages",
      mode: "ask_every_time"
    )
    expect(user.automation_permission_changes.sole).to have_attributes(
      actor: user,
      action: "created",
      previous_mode: "disabled",
      new_mode: "ask_every_time"
    )
  end

  it "serializes first-time writes on the stable permission owner" do
    expect(user).to receive(:with_lock).and_call_original

    described_class.call(
      user:,
      actor: user,
      capability: :draft_messages,
      mode: "ask_every_time"
    )
  end

  it "does not persist or audit the conservative default" do
    expect do
      described_class.call(user:, actor: user, capability: :send_reminders, mode: "disabled")
    end.not_to change(AutomationPermission, :count)

    expect(AutomationPermissionChange.count).to eq(0)
  end

  it "persists an explicit disabled relationship override over an automatic account default" do
    profile = create(:relationship_profile, user:)
    create(:automation_permission, user:, capability: "draft_messages", mode: "allow_automatically")

    permission = described_class.call(
      user:,
      actor: user,
      relationship_profile: profile,
      capability: :draft_messages,
      mode: "disabled"
    )

    expect(permission).to be_persisted
    expect(permission).to have_attributes(relationship_profile_id: profile.id, mode: "disabled")
    expect(AutomationPermission.decision_for(user:, capability: :draft_messages, relationship_profile: profile).mode)
      .to eq("disabled")
  end

  it "records the previous mode when a permission changes" do
    permission = create(:automation_permission, user:, mode: "ask_every_time")

    described_class.call(
      user:,
      actor: user,
      capability: permission.capability,
      mode: "allow_automatically"
    )

    expect(permission.reload.mode).to eq("allow_automatically")
    expect(user.automation_permission_changes.sole).to have_attributes(
      action: "updated",
      previous_mode: "ask_every_time",
      new_mode: "allow_automatically"
    )
  end

  it "rejects a relationship outside the user's account before writing" do
    foreign_profile = create(:relationship_profile)

    expect do
      described_class.call(
        user:,
        actor: user,
        relationship_profile: foreign_profile,
        capability: :make_reservations,
        mode: "ask_every_time"
      )
    end.to raise_error(ActiveRecord::RecordNotFound)

    expect(AutomationPermission.count).to eq(0)
    expect(AutomationPermissionChange.count).to eq(0)
  end

  it "rolls back the permission when the audit event cannot be written" do
    allow(AutomationPermissionChange).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

    expect do
      described_class.call(user:, actor: user, capability: :draft_messages, mode: "ask_every_time")
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(AutomationPermission.count).to eq(0)
  end

  it "removes an override and records the removal" do
    permission = create(
      :automation_permission,
      user:,
      relationship_profile: create(:relationship_profile, user:),
      capability: "make_reservations",
      mode: "ask_every_time"
    )

    described_class.remove!(permission:, actor: user)

    expect { permission.reload }.to raise_error(ActiveRecord::RecordNotFound)
    expect(user.automation_permission_changes.sole).to have_attributes(
      action: "removed",
      previous_mode: "ask_every_time",
      new_mode: nil
    )
  end

  it "locks the owner before the permission when removing an override" do
    permission = create(
      :automation_permission,
      user:,
      relationship_profile: create(:relationship_profile, user:),
      capability: "make_reservations",
      mode: "ask_every_time"
    )

    expect(user).to receive(:with_lock).ordered.and_call_original
    expect(permission).to receive(:lock!).ordered.and_call_original

    described_class.new(user:, actor: user).remove!(permission:)
  end
end
