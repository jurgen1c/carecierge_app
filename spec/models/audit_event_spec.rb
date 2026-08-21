# == Schema Information
#
# Table name: audit_events
# Database name: primary
#
#  id          :uuid             not null, primary key
#  action      :string           not null
#  actor_kind  :string           not null
#  metadata    :jsonb            not null
#  occurred_at :datetime         not null
#  source      :string           not null
#  target_type :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  actor_id    :uuid
#  target_id   :uuid
#  user_id     :uuid             not null
#
# Indexes
#
#  index_audit_events_on_action_and_occurred_at     (action,occurred_at DESC)
#  index_audit_events_on_actor_id                   (actor_id)
#  index_audit_events_on_source_and_occurred_at     (source,occurred_at DESC)
#  index_audit_events_on_target_type_and_target_id  (target_type,target_id)
#  index_audit_events_on_user_id                    (user_id)
#  index_audit_events_on_user_id_and_occurred_at    (user_id,occurred_at DESC)
#
# Foreign Keys
#
#  fk_rails_...  (actor_id => users.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe AuditEvent, type: :model do
  it "stores a privacy-minimized event with an owned user actor and optional target" do
    user = create(:user)
    profile = create(:relationship_profile, user:)

    event = create(
      :audit_event,
      user:,
      actor: user,
      target: profile,
      metadata: { "changed_fields" => "profile_details" }
    )

    expect(event).to have_attributes(
      user:,
      actor: user,
      actor_kind: "user",
      action: "relationship_profile.updated",
      source: "web_app",
      target: profile,
      metadata: { "changed_fields" => "profile_details" }
    )
  end

  it "supports the trust-sensitive action catalog without requiring nonexistent workflows" do
    expect(described_class::ACTIONS).to include(
      "approval.granted",
      "permission.changed",
      "sensitive_record.accessed",
      "data_export.requested",
      "data_deletion.requested",
      "automation.performed"
    )
    expect(described_class::ACTIONS).to include(
      "gift_recommendation.generated",
      "gift_recommendation.saved",
      "gift_recommendation.dismissed",
      "gift_recommendation.purchased"
    )
  end

  it "rejects arbitrary metadata keys and nested payloads" do
    unknown_key = build(:audit_event, metadata: { "content" => "private note" })
    nested_payload = build(:audit_event, metadata: { "changed_fields" => { "notes" => "private note" } })

    expect(unknown_key).not_to be_valid
    expect(unknown_key.errors[:metadata]).to be_present
    expect(nested_payload).not_to be_valid
    expect(nested_payload.errors[:metadata]).to be_present
  end

  it "requires user actors to belong to the account or be an admin" do
    owner = create(:user)
    foreign_actor = create(:user)
    admin = create(:user, :admin)

    expect(build(:audit_event, user: owner, actor: foreign_actor)).not_to be_valid
    expect(build(:audit_event, user: owner, actor: admin)).to be_valid
  end

  it "rejects targets owned by another account and unsupported polymorphic types" do
    owner = create(:user)
    foreign_profile = create(:relationship_profile)
    unsupported_target = create(:feature_flag)

    foreign_event = build(:audit_event, user: owner, actor: owner, target: foreign_profile)
    unsupported_event = build(:audit_event, user: owner, actor: owner, target: unsupported_target)

    expect(foreign_event).not_to be_valid
    expect(foreign_event.errors[:target]).to be_present
    expect(unsupported_event).not_to be_valid
    expect(unsupported_event.errors[:target_type]).to be_present
  end

  it "requires an actor only for user-originated events" do
    expect(build(:audit_event, actor_kind: "user", actor: nil)).not_to be_valid
    expect(build(:audit_event, actor_kind: "automation", actor: nil, source: "automation")).to be_valid
    expect(build(:audit_event, actor_kind: "system", actor: create(:user))).not_to be_valid
  end

  it "is append-only after persistence" do
    event = create(:audit_event)

    expect(event).to be_readonly
    expect { event.update!(source: "system") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    expect { event.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  it "nullifies a deleted target without deleting the audit event" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    event = create(:audit_event, user:, actor: user, target: profile)

    profile.destroy!

    expect(event.reload).to have_attributes(target: nil, target_type: nil, target_id: nil)
  end

  it "refuses to create an event for a target deleted before insertion" do
    user = create(:user)
    profile = create(:relationship_profile, user:)
    profile.destroy!

    expect do
      described_class.record!(
        user:,
        actor: user,
        action: "relationship_profile.updated",
        target: profile
      )
    end.to raise_error(ActiveRecord::RecordNotFound)
    expect(described_class.count).to eq(0)
  end

  it "indexes the complete global ledger ordering" do
    index = described_class.connection.indexes(described_class.table_name)
      .find { |candidate| candidate.name == "index_audit_events_on_global_order" }

    expect(index&.columns).to eq(%w[occurred_at created_at id])
    expect(index&.orders).to eq(:desc)
  end
end
