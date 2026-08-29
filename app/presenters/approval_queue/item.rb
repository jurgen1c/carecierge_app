module ApprovalQueue
  class Item
    attr_reader :approval_request

    delegate :id, :kind, :risk_level, :confidence, :action_key, :status, :lock_version,
      :approval_decisions, :created_at, :deferred_until, :subject_updated_at, to: :approval_request

    def initialize(approval_request:)
      @approval_request = approval_request
    end

    def subject
      approval_request.subject
    end

    def title
      return I18n.t("approvals.detail.superseded_title") if superseded?
      return I18n.t("approvals.detail.source_changed_title") if source_changed_since_review?

      subject.is_a?(ExtractedMemory) ? subject.display_title : subject.title
    end

    def relationship_name
      subject.relationship_profile.display_name
    end

    def type_label
      I18n.t("approvals.kinds.#{kind}")
    end

    def source_label
      return I18n.t("approvals.detail.superseded_source") if superseded?
      return I18n.t("approvals.detail.source_changed_source") if source_changed_since_review?
      return I18n.t("approvals.detail.reviewed_source") if subject.is_a?(ExtractedMemory) && decision_recorded?

      case subject
      when ExtractedMemory then subject.conversation_recap.title
      when MemoryRecord then subject.source_label
      end
    end

    def source_context
      return I18n.t("approvals.detail.superseded_context") if superseded?
      return I18n.t("approvals.detail.source_changed_context") if source_changed_since_review?

      case subject
      when ExtractedMemory then subject.source_excerpt
      when MemoryRecord then subject.body
      end
    end

    def proposed_action
      return I18n.t("approvals.detail.superseded_action") if superseded?
      return I18n.t("approvals.detail.source_changed_action") if source_changed_since_review?

      I18n.t("approvals.actions.#{action_key}.proposal", title:)
    end

    def source_changed_since_review?
      decision_recorded? && subject_updated_at != subject.updated_at
    end

    def superseded?
      status == "superseded"
    end

    def consequence
      return I18n.t("approvals.detail.superseded_consequence") if superseded?

      I18n.t("approvals.actions.#{action_key}.consequence", relationship: relationship_name)
    end

    def will_not_happen
      return I18n.t("approvals.detail.superseded_will_not_happen") if superseded?

      I18n.t("approvals.actions.#{action_key}.will_not_happen")
    end

    def reversible
      return I18n.t("approvals.detail.superseded_reversibility") if superseded?

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

    private

    def decision_recorded?
      status.in?(%w[approved rejected dismissed])
    end
  end
end
