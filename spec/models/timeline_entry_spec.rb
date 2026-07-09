# == Schema Information
#
# Table name: timeline_entries
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  body                    :text
#  entry_type              :string           not null
#  occurred_at             :datetime         not null
#  origin                  :string           default("manual"), not null
#  source_record_type      :string
#  title                   :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  source_record_id        :uuid
#
# Indexes
#
#  idx_on_relationship_profile_id_entry_type_7a425876dd          (relationship_profile_id,entry_type)
#  idx_on_relationship_profile_id_occurred_at_81b70cd1a8         (relationship_profile_id,occurred_at)
#  idx_on_source_record_type_source_record_id_f700104f25         (source_record_type,source_record_id)
#  index_timeline_entries_on_relationship_profile_id             (relationship_profile_id)
#  index_timeline_entries_on_relationship_profile_id_and_origin  (relationship_profile_id,origin)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
require "rails_helper"

RSpec.describe TimelineEntry, type: :model do
  describe "validations" do
    it "requires supported entry types and origins" do
      entry = build(:timeline_entry, entry_type: "unknown", origin: "imported")

      expect(entry).not_to be_valid
      expect(entry.errors[:entry_type]).to include("is not included in the list")
      expect(entry.errors[:origin]).to include("is not included in the list")
    end

    it "normalizes title and body text" do
      entry = build(:timeline_entry, title: "  Followed   up  ", body: "  Sent the invitation.  ")

      entry.valid?

      expect(entry.title).to eq("Followed up")
      expect(entry.body).to eq("Sent the invitation.")
    end
  end

  describe ".ordered" do
    it "orders newest events first while keeping titles stable for ties" do
      profile = create(:relationship_profile)
      older = create(:timeline_entry, relationship_profile: profile, title: "Older", occurred_at: Time.zone.local(2026, 7, 1, 10, 0, 0))
      same_time_b = create(:timeline_entry, relationship_profile: profile, title: "Zoo plan", occurred_at: Time.zone.local(2026, 7, 8, 10, 0, 0))
      same_time_a = create(:timeline_entry, relationship_profile: profile, title: "Apology sent", occurred_at: Time.zone.local(2026, 7, 8, 10, 0, 0))
      newer = create(:timeline_entry, relationship_profile: profile, title: "Newest", occurred_at: Time.zone.local(2026, 7, 9, 10, 0, 0))

      expect(profile.timeline_entries.ordered).to eq([ newer, same_time_a, same_time_b, older ])
    end
  end

  describe ".of_type" do
    it "filters by supported type and ignores unsupported filter values" do
      profile = create(:relationship_profile)
      note = create(:timeline_entry, relationship_profile: profile, entry_type: "note")
      gift = create(:timeline_entry, relationship_profile: profile, entry_type: "gift")

      expect(profile.timeline_entries.of_type("gift")).to contain_exactly(gift)
      expect(profile.timeline_entries.of_type("unknown")).to contain_exactly(note, gift)
    end
  end

  describe "source references" do
    it "can reference an existing source object without owning its lifecycle" do
      gift = create(:gift, name: "Concert tickets")
      entry = create(:timeline_entry, relationship_profile: gift.relationship_profile, source_record: gift, entry_type: "gift")

      expect(entry.source_record).to eq(gift)
      expect(entry.source_record_label).to eq("Gift: Concert tickets")

      entry.destroy!

      expect(Gift.exists?(gift.id)).to be(true)
    end

    it "rejects source objects from another relationship profile" do
      profile = create(:relationship_profile)
      other_gift = create(:gift, name: "Private tickets")
      entry = build(:timeline_entry, relationship_profile: profile, source_record: other_gift, entry_type: "gift")

      expect(entry).not_to be_valid
      expect(entry.errors[:source_record]).to include("must belong to the same relationship profile")
    end
  end
end
