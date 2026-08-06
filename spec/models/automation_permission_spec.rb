# == Schema Information
#
# Table name: automation_permissions
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  capability              :string           not null
#  mode                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid
#  user_id                 :uuid             not null
#
# Indexes
#
#  idx_automation_permissions_account_defaults              (user_id,capability) UNIQUE WHERE (relationship_profile_id IS NULL)
#  idx_automation_permissions_relationship_overrides        (user_id,relationship_profile_id,capability) UNIQUE WHERE (relationship_profile_id IS NOT NULL)
#  index_automation_permissions_on_relationship_profile_id  (relationship_profile_id)
#  index_automation_permissions_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe AutomationPermission, type: :model do
  it "accepts a declared mode for a catalog capability" do
    permission = build(:automation_permission, capability: "draft_messages", mode: "allow_automatically")

    expect(permission).to be_valid
  end

  it "rejects automatic execution for a high-impact capability" do
    permission = build(:automation_permission, capability: "make_purchases", mode: "allow_automatically")

    expect(permission).not_to be_valid
    expect(permission.errors[:mode]).to be_present
  end

  it "rejects a relationship outside the account boundary" do
    permission = build(
      :automation_permission,
      user: create(:user),
      relationship_profile: create(:relationship_profile),
      capability: "make_reservations"
    )

    expect(permission).not_to be_valid
    expect(permission.errors[:relationship_profile]).to be_present
  end

  it "keeps one account default and one override per relationship and capability" do
    global = create(:automation_permission)
    duplicate_global = build(:automation_permission, user: global.user, capability: global.capability)
    override = create(
      :automation_permission,
      user: global.user,
      relationship_profile: create(:relationship_profile, user: global.user),
      capability: global.capability
    )
    duplicate_override = build(
      :automation_permission,
      user: global.user,
      relationship_profile: override.relationship_profile,
      capability: global.capability
    )

    expect(duplicate_global).not_to be_valid
    expect(duplicate_override).not_to be_valid
  end

  describe ".decision_for" do
    let(:user) { create(:user) }
    let(:profile) { create(:relationship_profile, user:) }

    it "fails closed when the user has not configured a capability" do
      decision = described_class.decision_for(user:, capability: :draft_messages)

      expect(decision.mode).to eq("disabled")
      expect(decision.permits_execution?).to be(false)
    end

    it "uses a relationship override ahead of the account default" do
      create(:automation_permission, user:, capability: "make_reservations", mode: "allow_automatically")
      create(
        :automation_permission,
        user:,
        relationship_profile: profile,
        capability: "make_reservations",
        mode: "ask_every_time"
      )

      decision = described_class.decision_for(user:, capability: :make_reservations, relationship_profile: profile)

      expect(decision.mode).to eq("ask_every_time")
      expect(decision).to be_approval_required
    end

    it "fails closed for an archived relationship" do
      create(
        :automation_permission,
        user:,
        relationship_profile: profile,
        capability: "draft_messages",
        mode: "allow_automatically"
      )
      profile.discard!

      decision = described_class.decision_for(user:, capability: :draft_messages, relationship_profile: profile)

      expect(decision.mode).to eq("disabled")
    end

    it "fails closed when the supplied relationship instance has stale archive state" do
      create(:automation_permission, user:, capability: "draft_messages", mode: "allow_automatically")
      create(
        :automation_permission,
        user:,
        relationship_profile: profile,
        capability: "draft_messages",
        mode: "allow_automatically"
      )
      stale_profile = described_class.find_by!(relationship_profile: profile).relationship_profile
      RelationshipProfile.find(profile.id).discard!

      decision = described_class.decision_for(
        user:,
        capability: :draft_messages,
        relationship_profile: stale_profile
      )

      expect(stale_profile).not_to be_discarded
      expect(decision.mode).to eq("disabled")
      expect(decision.permits_execution?).to be(false)
    end

    it "rejects an unknown capability" do
      expect { described_class.decision_for(user:, capability: :unknown) }.to raise_error(KeyError)
    end
  end
end
