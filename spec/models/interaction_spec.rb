# == Schema Information
#
# Table name: interactions
# Database name: primary
#
#  id                      :uuid             not null, primary key
#  interaction_type        :string           not null
#  notes                   :text
#  occurred_at             :datetime         not null
#  origin                  :string           default("manual"), not null
#  source_type             :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  relationship_profile_id :uuid             not null
#  source_id               :uuid
#
# Indexes
#
#  idx_on_relationship_profile_id_occurred_at_id_afacfa9a3b  (relationship_profile_id,occurred_at DESC,id)
#  index_interactions_on_relationship_profile_id             (relationship_profile_id)
#  index_interactions_on_unique_source                       (source_type,source_id) UNIQUE WHERE (source_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (relationship_profile_id => relationship_profiles.id) ON DELETE => cascade
#
require "rails_helper"

RSpec.describe Interaction, type: :model do
  describe "manual and derived invariants" do
    it "accepts normalized manual interactions without a source" do
      interaction = build(:interaction, notes: "  Caught up   after work.  ")

      expect(interaction).to be_valid
      interaction.valid?
      expect(interaction.notes).to eq("Caught up after work.")
      expect(interaction).to be_manual
    end

    it "requires a supported type and source provenance for derived interactions" do
      interaction = build(:interaction, origin: "derived", interaction_type: "unknown", source: nil)

      expect(interaction).not_to be_valid
      expect(interaction.errors[:interaction_type]).to be_present
      expect(interaction.errors[:source]).to be_present
    end

    it "keeps manual and derived types paired with their origin" do
      manual = build(:interaction, interaction_type: "conversation_recap")
      derived = build(:interaction, :derived_from_conversation_recap, interaction_type: "call")

      expect(manual).not_to be_valid
      expect(manual.errors[:interaction_type]).to be_present
      expect(derived).not_to be_valid
      expect(derived.errors[:interaction_type]).to be_present
    end

    it "allows the present boundary but rejects future interactions" do
      now = Time.zone.local(2026, 7, 14, 12)

      Timecop.freeze(now) do
        expect(build(:interaction, occurred_at: now)).to be_valid

        future = build(:interaction, occurred_at: now + 1.second)
        expect(future).not_to be_valid
        expect(future.errors[:occurred_at]).to be_present
      end
    end

    it "rejects a source from another relationship profile" do
      recap = create(:conversation_recap)
      interaction = build(:interaction, :derived_from_conversation_recap, relationship_profile: create(:relationship_profile), source: recap)

      expect(interaction).not_to be_valid
      expect(interaction.errors[:source]).to be_present
    end

    it "allows each source to produce only one interaction" do
      existing = create(:interaction, :derived_from_conversation_recap)
      duplicate = build(:interaction, :derived_from_conversation_recap, source: existing.source, relationship_profile: existing.relationship_profile)

      expect(duplicate).not_to be_valid
    end
  end

  describe ".ordered" do
    it "orders newest interactions first with stable ID ties" do
      profile = create(:relationship_profile)
      older = create(:interaction, relationship_profile: profile, occurred_at: Time.zone.local(2026, 7, 1, 10))
      tie_b = create(:interaction, id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", relationship_profile: profile, occurred_at: Time.zone.local(2026, 7, 8, 10))
      tie_a = create(:interaction, id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", relationship_profile: profile, occurred_at: Time.zone.local(2026, 7, 8, 10))

      expect(profile.interactions.ordered).to eq([ tie_a, tie_b, older ])
    end
  end

  describe ".sync_from_source!" do
    it "creates and updates one traceable interaction for a conversation recap" do
      recap = create(:conversation_recap, title: "Lunch", body: "Talked about work.")

      expect do
        described_class.sync_from_source!(recap)
      end.to change(described_class, :count).by(1)

      interaction = recap.interaction
      expect(interaction).to have_attributes(
        relationship_profile: recap.relationship_profile,
        origin: "derived",
        interaction_type: "conversation_recap",
        occurred_at: recap.occurred_at,
        source: recap
      )
      expect(interaction.display_notes).to eq("Talked about work.")

      recap.update!(body: "Talked about a new role.", occurred_at: Time.zone.local(2026, 7, 9, 12))
      expect { described_class.sync_from_source!(recap) }.not_to change(described_class, :count)
      expect(interaction.reload.occurred_at).to eq(recap.occurred_at)
      expect(interaction.display_notes).to eq("Talked about a new role.")
    end

    it "derives display notes from a mood note without copying private source text" do
      mood_note = create(:mood_note, observation: "Seemed more at ease.")

      interaction = described_class.sync_from_source!(mood_note)

      expect(interaction).to have_attributes(origin: "derived", interaction_type: "mood_note", notes: nil)
      expect(interaction.display_notes).to eq("Seemed more at ease.")
    end
  end
end
