# == Schema Information
#
# Table name: contact_cadences
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  interval_days           :integer          not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_contact_cadences_on_relationship_profile_id  (relationship_profile_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe ContactCadence, type: :model do
  describe ".suggested_interval_days_for" do
    it "varies suggestions by relationship type without persisting them" do
      parent = build(:relationship_profile, type: "RelationshipProfiles::Mother")
      friend = build(:relationship_profile, type: "RelationshipProfiles::Friend")
      client = build(:relationship_profile, type: "RelationshipProfiles::Client")
      acquaintance = build(:relationship_profile, type: "RelationshipProfiles::Acquaintance")

      expect(described_class.suggested_interval_days_for(parent)).to eq(7)
      expect(described_class.suggested_interval_days_for(friend)).to eq(14)
      expect(described_class.suggested_interval_days_for(client)).to eq(30)
      expect(described_class.suggested_interval_days_for(acquaintance)).to eq(90)
      expect(parent.contact_cadence).to be_nil
    end
  end

  describe "validations" do
    it "allows one supported cadence per relationship profile" do
      existing = create(:contact_cadence, interval_days: 14)
      duplicate = build(:contact_cadence, relationship_profile: existing.relationship_profile, interval_days: 7)
      unsupported = build(:contact_cadence, interval_days: 13)

      expect(duplicate).not_to be_valid
      expect(unsupported).not_to be_valid
      expect(unsupported.errors[:interval_days]).to be_present
    end
  end

  describe "check-in state" do
    it "uses the newest meaningful interaction as its next check-in anchor" do
      cadence = create(:contact_cadence, interval_days: 14)
      create(:interaction, relationship_profile: cadence.relationship_profile, occurred_at: Time.zone.local(2026, 7, 1, 10))
      create(:interaction, relationship_profile: cadence.relationship_profile, occurred_at: Time.zone.local(2026, 7, 8, 10))

      expect(cadence.last_interaction_at).to eq(Time.zone.local(2026, 7, 8, 10))
      expect(cadence.next_check_in_at).to eq(Time.zone.local(2026, 7, 22, 10))
      expect(cadence).not_to be_overdue(as_of: Time.zone.local(2026, 7, 22, 9, 59))
      expect(cadence).to be_overdue(as_of: Time.zone.local(2026, 7, 22, 10, 1))
    end

    it "starts a newly accepted rhythm without claiming an immediate missed interaction" do
      Timecop.freeze(Time.zone.local(2026, 7, 14, 9)) do
        cadence = create(:contact_cadence, interval_days: 7)

        expect(cadence.last_interaction_at).to be_nil
        expect(cadence.next_check_in_at).to eq(Time.zone.local(2026, 7, 21, 9))
        expect(cadence).not_to be_overdue
      end
    end
  end
end
