require "rails_helper"

RSpec.describe AutomationPermissions::UpdateDefaults do
  let(:user) { create(:user) }

  it "updates account defaults and audit events in one transaction" do
    described_class.call(
      user:,
      actor: user,
      modes: {
        draft_messages: "allow_automatically",
        make_purchases: "ask_every_time"
      }
    )

    expect(user.automation_permissions.account_defaults.pluck(:capability, :mode)).to contain_exactly(
      [ "draft_messages", "allow_automatically" ],
      [ "make_purchases", "ask_every_time" ]
    )
    expect(user.automation_permission_changes.pluck(:capability)).to contain_exactly(
      "draft_messages",
      "make_purchases"
    )
  end

  it "locks the owner once for the entire batch" do
    expect(user).to receive(:with_lock).once.and_call_original

    described_class.call(
      user:,
      actor: user,
      modes: {
        draft_messages: "allow_automatically",
        make_purchases: "ask_every_time"
      }
    )
  end

  it "rejects unknown capabilities before writing any changes" do
    expect do
      described_class.call(
        user:,
        actor: user,
        modes: { draft_messages: "ask_every_time", unknown: "allow_automatically" }
      )
    end.to raise_error(KeyError)

    expect(AutomationPermission.count).to eq(0)
    expect(AutomationPermissionChange.count).to eq(0)
  end

  it "rolls back every default when one mode violates its capability policy" do
    expect do
      described_class.call(
        user:,
        actor: user,
        modes: { draft_messages: "ask_every_time", make_purchases: "allow_automatically" }
      )
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(AutomationPermission.count).to eq(0)
    expect(AutomationPermissionChange.count).to eq(0)
  end
end
