require "rails_helper"

RSpec.describe RelationshipPersona, type: :model do
  subject(:persona) { described_class.new(relationship_profile: profile) }

  let(:profile) { create(:relationship_profile, preferred_name: "Maya") }

  describe "#traits" do
    it "builds ordered, source-backed traits from reviewed memories and structured preferences" do
      confirmed_preference = create(
        :relationship_preference,
        relationship_profile: profile,
        key: "Gift style",
        value: "Practical gifts",
        confidence: "confirmed",
        source_notes: "Maya asked for something useful."
      )
      inferred_preference = create(
        :relationship_preference,
        relationship_profile: profile,
        key: "Gathering style",
        value: "Planned gatherings",
        confidence: "medium",
        source_notes: "Three recent plans were scheduled ahead."
      )
      confirmed_memory = create(
        :memory_record,
        relationship_profile: profile,
        title: "Direct communicator",
        body: "Maya asked for clear, direct updates.",
        source: "user_corrected",
        confidence: "high",
        status: "corrected"
      )
      inferred_memory = create(
        :memory_record,
        relationship_profile: profile,
        title: "Quiet birthday plans",
        body: "Smaller birthday dinners were well received.",
        source: "ai_inferred",
        confidence: "medium"
      )

      expect(persona.traits.map(&:source)).to contain_exactly(
        confirmed_preference,
        inferred_preference,
        confirmed_memory,
        inferred_memory
      )
      expect(persona.traits.map(&:certainty)).to eq(%w[confirmed confirmed inferred inferred])
      expect(persona.traits.map(&:statement)).to eq(
        [
          "Direct communicator",
          "Gift style",
          "Seems to suggest: Gathering style",
          "Seems to suggest: Quiet birthday plans"
        ]
      )
      expect(persona.traits.find { |trait| trait.source == confirmed_preference }.evidence).to eq("Maya asked for something useful.")
      expect(persona.traits.find { |trait| trait.source == confirmed_memory }.evidence).to eq("Maya asked for clear, direct updates.")
    end

    it "excludes protected, stale, review-needed, and archived memories" do
      included = create(:memory_record, relationship_profile: profile, title: "Included")
      protected = create(:memory_record, relationship_profile: profile, title: "Protected")
      create(:privacy_vault_item, relationship_profile: profile, protectable: protected)
      create(:memory_record, relationship_profile: profile, title: "Needs review", status: "needs_review")
      create(:memory_record, relationship_profile: profile, title: "Archived", status: "archived")

      Timecop.freeze(Time.zone.local(2026, 8, 8, 10, 0, 0)) do
        create(:memory_record, relationship_profile: profile, title: "Stale", stale_after: Date.new(2026, 8, 7))

        expect(persona.traits.map(&:source)).to eq([ included ])
      end
    end

    it "does not present high confidence alone as user confirmation" do
      preference = create(:relationship_preference, relationship_profile: profile, key: "Conversation style", confidence: "high")
      imported_memory = create(:memory_record, relationship_profile: profile, title: "Planning style", source: "imported", confidence: "high")

      expect(persona.traits.map(&:source)).to contain_exactly(preference, imported_memory)
      expect(persona.traits.map(&:certainty)).to eq(%w[inferred inferred])
      expect(persona.traits.map(&:statement)).to all(start_with("Seems to suggest:"))
    end
  end

  describe "#summary" do
    it "summarizes the current traits without removing uncertainty language" do
      create(:relationship_preference, relationship_profile: profile, key: "Gift style", value: "Practical", confidence: "confirmed")
      create(:relationship_preference, relationship_profile: profile, key: "Gathering style", value: "Planned", confidence: "inferred")

      expect(persona.summary).to eq("Gift style and Seems to suggest: Gathering style")
    end
  end

  describe "#suggestion_inputs" do
    it "exposes evidence and certainty without presenting inferences as facts" do
      preference = create(
        :relationship_preference,
        relationship_profile: profile,
        key: "Gathering style",
        value: "Planned gatherings",
        confidence: "low",
        source_notes: "Recent events were planned ahead."
      )

      expect(persona.suggestion_inputs).to eq(
        [
          {
            statement: "Seems to suggest: Gathering style",
            detail: "Planned gatherings",
            certainty: "inferred",
            evidence: "Recent events were planned ahead.",
            source_type: "RelationshipPreference",
            source_id: preference.id
          }
        ]
      )
    end

    it "fails closed for an archived relationship profile" do
      create(:relationship_preference, relationship_profile: profile, confidence: "confirmed")
      profile.archive!

      expect(persona.suggestion_inputs).to be_empty
    end

    it "uses encrypted payloads only for protected memories explicitly allowed for suggestions" do
      allowed_memory = create(
        :memory_record,
        relationship_profile: profile,
        title: "Private celebration plan",
        body: "A quiet table was requested.",
        source: "ai_inferred",
        confidence: "medium"
      )
      excluded_memory = create(:memory_record, relationship_profile: profile, title: "Excluded private context")
      allowed_item = PrivacyVault::Protect.call(actor: profile.user, protectable: allowed_memory)
      PrivacyVault::Protect.call(actor: profile.user, protectable: excluded_memory)
      allowed_item.update!(suggestion_usage: "allowed")

      expect(persona.traits).to be_empty
      expect(persona.suggestion_inputs).to eq(
        [
          {
            statement: "Seems to suggest: Private celebration plan",
            detail: "A quiet table was requested.",
            certainty: "inferred",
            evidence: "A quiet table was requested.",
            source_type: "MemoryRecord",
            source_id: allowed_memory.id
          }
        ]
      )
    end
  end
end
