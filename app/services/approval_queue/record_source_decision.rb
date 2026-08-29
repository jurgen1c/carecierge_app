module ApprovalQueue
  class RecordSourceDecision
    class DecisionConflict < StandardError; end

    EXTRACTED_MEMORY_DECISIONS = {
      "approved" => "approve",
      "rejected" => "reject",
      "corrected" => "edit"
    }.freeze

    def self.call(user:, subject:, decision:, corrected_title: nil, corrected_body: nil)
      new(user:, subject:, decision:, corrected_title:, corrected_body:).call
    end

    def initialize(user:, subject:, decision:, corrected_title:, corrected_body:)
      @user = user
      @subject = subject
      @decision = decision.to_s
      @corrected_title = corrected_title
      @corrected_body = corrected_body
    end

    def call
      validate_decision!
      user.with_lock("FOR NO KEY UPDATE") do
        subject.relationship_profile.with_lock do
          subject.lock!
          request = find_or_create_request
          return subject unless request

          ApprovalDecisions::Apply.call(
            approval_request: request,
            actor: user,
            decision: queue_decision,
            lock_version: request.lock_version,
            corrected_title:,
            corrected_body:,
            override_deferral: true,
            override_source_version: true
          )
        end
      end
    end

    private

    attr_reader :user, :subject, :decision, :corrected_title, :corrected_body

    def find_or_create_request
      action_key = Eligibility.action_key(subject)
      existing = user.approval_requests.open.find_by(subject:, action_key:)
      return existing if existing
      return if decision_already_applied?
      raise DecisionConflict if mismatched_terminal_decision?

      unless Eligibility.eligible?(subject, action_key:)
        raise ActiveRecord::RecordInvalid, subject
      end

      user.approval_requests.create!(
        subject:,
        kind: Eligibility.kind(subject),
        action_key:,
        risk_level: Eligibility.risk_level(subject, action_key:),
        confidence: subject.confidence,
        subject_updated_at: subject.updated_at
      )
    rescue ActiveRecord::RecordNotUnique
      user.approval_requests.open.find_by!(subject:, action_key: Eligibility.action_key(subject))
    end

    def validate_decision!
      allowed = subject.is_a?(ExtractedMemory) ? %w[approve reject correct] : %w[approve]
      return if decision.in?(allowed)

      raise ArgumentError, "Unsupported source decision"
    end

    def queue_decision
      decision == "correct" ? "edit" : decision
    end

    def decision_already_applied?
      case subject
      when ExtractedMemory
        return false unless EXTRACTED_MEMORY_DECISIONS[subject.status] == queue_decision
        return true unless queue_decision == "edit"

        subject.correction_matches?(title: corrected_title, body: corrected_body)
      when MemoryRecord then queue_decision == "approve" && subject.high_impact_automation_allowed?
      else false
      end
    end

    def mismatched_terminal_decision?
      subject.is_a?(ExtractedMemory) && !subject.pending?
    end
  end
end
