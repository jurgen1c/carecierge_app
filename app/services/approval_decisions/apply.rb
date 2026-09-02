module ApprovalDecisions
  class Apply
    DECISIONS = %w[approve reject edit defer dismiss].freeze

    def self.call(
      approval_request:,
      actor:,
      decision:,
      lock_version:,
      corrected_title: nil,
      corrected_body: nil,
      deferred_until: nil,
      override_deferral: false,
      override_source_version: false
    )
      new(
        approval_request:,
        actor:,
        decision:,
        lock_version:,
        corrected_title:,
        corrected_body:,
        deferred_until:,
        override_deferral:,
        override_source_version:
      ).call
    end

    def initialize(approval_request:, actor:, decision:, lock_version:, corrected_title:, corrected_body:, deferred_until:, override_deferral:, override_source_version:)
      @approval_request = approval_request
      @actor = actor
      @decision = decision.to_s
      @expected_lock_version = parse_lock_version(lock_version)
      @corrected_title = corrected_title
      @corrected_body = corrected_body
      @deferred_until = deferred_until
      @override_deferral = override_deferral
      @override_source_version = override_source_version
    end

    def call
      authorize!
      raise ArgumentError, "Unsupported approval decision" unless decision.in?(DECISIONS)

      lock_subject do
        approval_request.reload
        approval_request.lock!
        raise ActiveRecord::StaleObjectError.new(approval_request, "update") unless approval_request.lock_version == expected_lock_version
        raise ActiveRecord::RecordInvalid, approval_request unless decision_allowed_now?
        raise ActiveRecord::RecordInvalid, approval_request unless relationship_active?
        authorize_subject_mutation!
        raise ActiveRecord::RecordInvalid, approval_request unless subject_eligible?
        verify_or_refresh_source_version!

        if extracted_memory_decision?
          review_extracted_memory
        else
          apply_to_subject
          transition_request!
          record_history!
          approval_request
        end
      end
    end

    private

    attr_reader :approval_request, :actor, :decision, :expected_lock_version, :corrected_title, :corrected_body,
      :deferred_until, :override_deferral, :override_source_version

    def parse_lock_version(value)
      Integer(value)
    rescue ArgumentError, TypeError
      raise ArgumentError, "Invalid lock version"
    end

    def decision_allowed_now?
      approval_request.open_for_decision? || override_deferral && approval_request.status == "deferred"
    end

    def subject_eligible?
      ApprovalQueue::Eligibility.eligible?(approval_request.subject, action_key: approval_request.action_key)
    end

    def relationship_active?
      approval_request.subject.relationship_profile.kept?
    end

    def authorize!
      return if actor.present? && approval_request.user_id == actor.id

      raise Pundit::NotAuthorizedError, "not allowed to decide this approval"
    end

    def authorize_subject_mutation!
      return unless approval_request.action_key == "approve_high_impact_memory" && decision == "approve"
      return if MemoryRecordPolicy.new(actor, approval_request.subject).approve_high_impact_automation?

      raise Pundit::NotAuthorizedError, "not allowed to approve this memory"
    end

    def source_version_current?
      approval_request.subject_updated_at == approval_request.subject.updated_at
    end

    def verify_or_refresh_source_version!
      return if source_version_current?
      unless override_source_version
        raise ActiveRecord::StaleObjectError.new(approval_request, "update")
      end

      attributes = {
        subject_updated_at: approval_request.subject.updated_at,
        confidence: approval_request.subject.confidence,
        risk_level: ApprovalQueue::Eligibility.risk_level(
          approval_request.subject,
          action_key: approval_request.action_key
        )
      }
      attributes.merge!(status: "pending", deferred_until: nil) if approval_request.open_for_decision?
      approval_request.update!(attributes)
    end

    def lock_subject(&block)
      subject = approval_request.subject
      profile = subject.respond_to?(:relationship_profile) ? subject.relationship_profile : nil

      ApplicationRecord.transaction do
        actor.with_lock("FOR NO KEY UPDATE") do
          if profile
            profile.with_lock do
              subject.lock!
              block.call
            end
          else
            subject.with_lock(&block)
          end
        end
      end
    end

    def apply_to_subject
      return if decision.in?(%w[defer dismiss])

      case approval_request.action_key
      when "approve_high_impact_memory" then review_high_impact_memory
      end
    end

    def extracted_memory_decision?
      approval_request.action_key == "review_extracted_memory" && decision.in?(%w[approve reject edit])
    end

    def review_extracted_memory
      source_decision = { "approve" => "approve", "reject" => "reject", "edit" => "correct" }.fetch(decision)
      MemoryExtractions::Review.call(
        extracted_memory: approval_request.subject,
        reviewer: actor,
        decision: source_decision,
        corrected_title:,
        corrected_body:,
        approval_request:,
        expected_lock_version: approval_request.lock_version
      )
    end

    def review_high_impact_memory
      raise ArgumentError, "Unsupported approval decision" if decision == "edit"

      approval_request.subject.approve_high_impact_automation! if decision == "approve"
    end

    def transition_request!
      attributes = case decision
      when "approve", "edit" then { status: "approved", decided_at: Time.current, deferred_until: nil }
      when "reject" then { status: "rejected", decided_at: Time.current, deferred_until: nil }
      when "dismiss" then { status: "dismissed", decided_at: Time.current, deferred_until: nil }
      when "defer" then { status: "deferred", deferred_until: parsed_deferred_until, decided_at: nil }
      end
      attributes[:subject_updated_at] = approval_request.subject.updated_at unless decision == "defer"
      approval_request.update!(attributes)
    end

    def parsed_deferred_until
      OwnerLocalCalendar.time_zone_for(user: actor).parse(deferred_until.to_s)
    rescue ArgumentError
      nil
    end

    def record_history!
      occurred_at = Time.current
      approval_request.approval_decisions.create!(user: actor, decision:, occurred_at:)

      AuditEvent.record!(
        user: actor,
        actor:,
        action: audit_action,
        target: approval_request,
        metadata: { request_kind: approval_request.kind, result: decision },
        occurred_at:
      )
    end

    def audit_action
      return "approval.granted" if decision.in?(%w[approve edit])

      { "reject" => "approval.rejected", "defer" => "approval.deferred", "dismiss" => "approval.dismissed" }.fetch(decision)
    end
  end
end
