require "rails_helper"

RSpec.describe Suggestion do
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
