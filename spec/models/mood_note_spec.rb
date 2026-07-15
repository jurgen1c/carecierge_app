# == Schema Information
#
# Table name: mood_notes
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  category                :string           not null
#  follow_up_at            :datetime
#  observation             :text             not null
#  observed_at             :datetime         not null
#  supportive_action       :text
#  timeline_visible        :boolean          default(FALSE), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#
# Indexes
#
#  index_mood_notes_on_relationship_profile_id                   (relationship_profile_id)
#  index_mood_notes_on_relationship_profile_id_and_category      (relationship_profile_id,category)
#  index_mood_notes_on_relationship_profile_id_and_follow_up_at  (relationship_profile_id,follow_up_at)
#  index_mood_notes_on_relationship_profile_id_and_observed_at   (relationship_profile_id,observed_at)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id)
#
require "rails_helper"

RSpec.describe MoodNote, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  describe "validations and normalization" do
    it "requires an observation, observed time, and supported category" do
      note = build(:mood_note, observation: "", observed_at: nil, category: "diagnosed")

      expect(note).not_to be_valid
      expect(note.errors[:observation]).to include("can't be blank")
      expect(note.errors[:category]).to include("is not included in the list")
    end

    it "trims user-authored text while preserving observation line breaks" do
      note = build(
        :mood_note,
        observation: "  Seemed proud after the presentation.\nPaused before sharing more.  ",
        supportive_action: "  Ask how the celebration went.  "
      )

      note.valid?

      expect(note.observation).to eq("Seemed proud after the presentation.\nPaused before sharing more.")
      expect(note.supportive_action).to eq("Ask how the celebration went.")
    end

    it "defaults the observed time before validation" do
      travel_to Time.zone.local(2026, 7, 13, 9, 15, 0) do
        note = build(:mood_note, observed_at: nil)

        note.valid?

        expect(note.observed_at).to eq(Time.zone.local(2026, 7, 13, 9, 15, 0))
      end
    end

    it "rejects future observation times at the source boundary" do
      now = Time.zone.local(2026, 7, 14, 12)

      travel_to now do
        note = build(:mood_note, observed_at: now + 1.second)

        expect(note).not_to be_valid
        expect(note.errors[:observed_at]).to include("can't be in the future")
      end
    end

    it "defaults timeline visibility off" do
      note = described_class.new

      expect(note.timeline_visible).to be(false)
    end

    it "does not replace a cleared observed time on an existing note" do
      note = create(:mood_note, observed_at: Time.zone.local(2026, 7, 12, 9, 15, 0))

      note.observed_at = nil

      expect(note).not_to be_valid
      expect(note.errors[:observed_at]).to include("can't be blank")
      expect(note.observed_at).to be_nil
    end

    it "uses a concise observation as its source-record title" do
      note = build(:mood_note, observation: "A" * 100)

      expect(note.display_title.length).to be <= 80
    end

    it "uses a normalized single-line source-record title" do
      note = build(:mood_note, observation: "Seemed proud.\n  Paused before sharing more.")

      expect(note.display_title).to eq("Seemed proud. Paused before sharing more.")
    end
  end

  describe ".ordered" do
    it "orders newest observations first with stable category and ID ties" do
      profile = create(:relationship_profile)
      older = create(:mood_note, relationship_profile: profile, observed_at: Time.zone.local(2026, 7, 10, 9, 0, 0))
      proud = create(:mood_note, relationship_profile: profile, category: "proud", observed_at: Time.zone.local(2026, 7, 12, 9, 0, 0))
      stressed_b = create(:mood_note, id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", relationship_profile: profile, category: "stressed", observed_at: proud.observed_at)
      stressed_a = create(:mood_note, id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", relationship_profile: profile, category: "stressed", observed_at: proud.observed_at)
      newer = create(:mood_note, relationship_profile: profile, observed_at: Time.zone.local(2026, 7, 13, 9, 0, 0))

      expect(profile.mood_notes.ordered).to eq([ newer, proud, stressed_a, stressed_b, older ])
    end
  end
end
