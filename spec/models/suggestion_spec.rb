require "rails_helper"

RSpec.describe Suggestion do
  describe "gesture variants" do
    it "requires supported effort metadata and fingerprints each alternative separately" do
      profile = create(:relationship_profile)
      reason = described_class::Reason.new(
        label_key: "suggestions.reasons.spontaneous",
        label_params: { name: profile.display_name },
        evidence: profile.relationship_type_label,
        certainty: "confirmed",
        source: profile
      )

      low = described_class.new(
        fingerprint: described_class.fingerprint_for(
          relationship_profile_id: profile.id,
          suggestion_type: "spontaneous",
          source_type: profile.class.base_class.name,
          source_id: profile.id,
          variant: "low"
        ),
        suggestion_type: "spontaneous",
        title_key: "suggestions.types.spontaneous.low.title",
        title_params: { name: profile.display_name },
        detail_key: "suggestions.types.spontaneous.low.detail",
        detail_params: { name: profile.display_name },
        reasons: [ reason ],
        action_kind: "create_reminder",
        action_attributes: {},
        effort: "low",
        variation: "low"
      )
      medium_fingerprint = described_class.fingerprint_for(
        relationship_profile_id: profile.id,
        suggestion_type: "spontaneous",
        source_type: profile.class.base_class.name,
        source_id: profile.id,
        variant: "medium"
      )

      expect(low).to be_gesture
      expect(low).to have_attributes(effort: "low", variation: "low", alternative_variation: "medium")
      expect(low.alternative_variation(excluding: [ "medium" ])).to eq("high")
      expect(low.alternative_variation(excluding: %w[medium high])).to be_nil
      expect(low.fingerprint).not_to eq(medium_fingerprint)
      expect do
        described_class.new(
          fingerprint: "invalid",
          suggestion_type: "spontaneous",
          title_key: "suggestions.types.spontaneous.low.title",
          title_params: {},
          detail_key: "suggestions.types.spontaneous.low.detail",
          detail_params: {},
          reasons: [ reason ],
          action_kind: "create_reminder",
          action_attributes: {},
          effort: "tiny",
          variation: "low"
        )
      end.to raise_error(ArgumentError, "unsupported gesture effort")
    end
  end

  describe "high-impact evidence" do
    it "fails closed for unapproved AI-inferred memory" do
      memory = build(
        :memory_record,
        source: "ai_inferred",
        confidence: "medium",
        high_impact_automation_approved_at: nil
      )
      reason = described_class::Reason.new(
        label_key: "suggestions.reasons.relationship_context",
        label_params: {},
        evidence: "A cautious inference",
        certainty: "inferred",
        source: memory
      )
      suggestion = described_class.new(
        fingerprint: "fingerprint",
        suggestion_type: "repair_focused",
        title_key: "suggestions.types.repair_focused.title",
        title_params: { name: "Maya" },
        detail_key: "suggestions.types.repair_focused.detail",
        detail_params: { name: "Maya" },
        reasons: [ reason ],
        action_kind: "create_reminder",
        action_attributes: {}
      )

      expect(suggestion).to be_high_impact
      expect(suggestion).not_to be_high_impact_evidence_eligible

      memory.high_impact_automation_approved_at = Time.current

      expect(suggestion).to be_high_impact_evidence_eligible
    end
  end
end
