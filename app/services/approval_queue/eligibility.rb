module ApprovalQueue
  module Eligibility
    module_function

    def eligible?(subject, action_key:, protected_memory_ids: nil)
      return false unless subject.relationship_profile.kept?

      case action_key
      when "review_extracted_memory"
        subject.is_a?(ExtractedMemory) && subject.status == "pending"
      when "approve_high_impact_memory"
        subject.is_a?(MemoryRecord) && high_impact_memory_eligible?(subject, protected_memory_ids:)
      else
        false
      end
    end

    def risk_level(subject, action_key:)
      return "high" if action_key == "approve_high_impact_memory"

      subject.confidence.in?(%w[low inferred]) ? "medium" : "low"
    end

    def kind(subject)
      case subject
      when ExtractedMemory then "extracted_memory"
      when MemoryRecord then "memory_record"
      else raise ArgumentError, "Unsupported approval subject"
      end
    end

    def action_key(subject)
      case subject
      when ExtractedMemory then "review_extracted_memory"
      when MemoryRecord then "approve_high_impact_memory"
      else raise ArgumentError, "Unsupported approval subject"
      end
    end

    def high_impact_memory_eligible?(subject, protected_memory_ids:)
      subject.high_impact_automation_approved_at.nil? &&
        subject.status != "archived" &&
        (subject.source == "ai_inferred" || subject.confidence.in?(%w[low inferred])) &&
        !vault_protected?(subject, protected_memory_ids:)
    end
    private_class_method :high_impact_memory_eligible?

    def vault_protected?(subject, protected_memory_ids:)
      return protected_memory_ids.key?(subject.id) if protected_memory_ids

      subject.association(:privacy_vault_item).reset
      subject.vault_protected?
    end
    private_class_method :vault_protected?
  end
end
