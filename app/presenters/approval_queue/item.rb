module ApprovalQueue
  class Item
    attr_reader :approval_request

    delegate :id, :kind, :risk_level, :confidence, :action_key, :status, :lock_version,
      :approval_decisions, :created_at, :deferred_until, to: :approval_request

    def initialize(approval_request:)
      @approval_request = approval_request
    end

    def subject
      approval_request.subject
    end

    def title
      subject.is_a?(ExtractedMemory) ? subject.display_title : subject.title
    end

    def relationship_name
      subject.relationship_profile.display_name
    end

    def type_label
      I18n.t("approvals.kinds.#{kind}")
    end

    def source_label
      case subject
      when ExtractedMemory then subject.conversation_recap.title
      when MemoryRecord then subject.source_label
      end
    end

    def source_context
      case subject
      when ExtractedMemory then subject.source_excerpt
      when MemoryRecord then subject.body
      end
    end

    def proposed_action
      I18n.t("approvals.actions.#{action_key}.proposal", title:)
    end

    def consequence
      I18n.t("approvals.actions.#{action_key}.consequence", relationship: relationship_name)
    end

    def will_not_happen
      I18n.t("approvals.actions.#{action_key}.will_not_happen")
    end

    def reversible
      I18n.t("approvals.actions.#{action_key}.reversible")
    end

    def edit_supported?
      action_key == "review_extracted_memory"
    end

    def corrected_title
      subject.respond_to?(:corrected_title) ? subject.corrected_title.presence || subject.title : subject.title
    end

    def corrected_body
      subject.respond_to?(:corrected_body) ? subject.corrected_body.presence || subject.body : subject.body
    end
  end
end
