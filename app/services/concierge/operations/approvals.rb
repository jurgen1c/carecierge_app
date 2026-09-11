module Concierge
  module Operations
    class Approvals < Base
      REQUIRES_PROFILE_ID = false
      SCOPE_FIELDS = { relationship_profile_id: :uuid }.freeze
      DECISION_FIELDS = SCOPE_FIELDS.merge(id: :uuid, lock_version: :integer).freeze

      def self.namespace = "approvals"

      def self.definitions
        [ define("search", description: "Read eligible pending, deferred or completed memory reviews. Follow next_page for older requests. These never authorize external actions.", fields: SCOPE_FIELDS.merge(status: %w[pending deferred completed], page: :integer), read_only: true),
          define("read", description: "Read an identified memory review with its source, risk, certainty and current edit version.", fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id], read_only: true),
          define("defer", description: "Defer an eligible review until the exact owner-local timestamp, without approving its source.", fields: DECISION_FIELDS.merge(deferred_until: :datetime), required: %w[id lock_version deferred_until]),
          define("dismiss", description: "Dismiss an eligible review from the queue without approving or deleting its source.", fields: DECISION_FIELDS, required: %w[id lock_version]) ] +
          %w[approve reject edit].map do |decision|
            fields = decision == "edit" ? DECISION_FIELDS.merge(corrected_title: :string, corrected_body: :string) : DECISION_FIELDS
            required = %w[id lock_version] + (decision == "edit" ? %w[corrected_title corrected_body] : [])
            define(decision, description: "Preview #{decision} for an eligible memory review using its last read lock_version. Approval of an inferred memory permits higher-impact use; extracted-memory edits save reviewed corrections. Requires exact inline confirmation.",
              fields:, required:, confirmation: true)
          end
      end

      def target
        return unless arguments["id"]
        @target ||= user.approval_requests.find(arguments["id"]).tap do |request|
          raise ActiveRecord::RecordNotFound unless ApprovalSources.visible?(request, user:, turn:)
        end
      end

      def profile
        record = target&.subject&.relationship_profile
        return record if record && (!arguments["relationship_profile_id"] || arguments["relationship_profile_id"] == record.id)
        raise ActiveRecord::RecordNotFound if record
        super if arguments["relationship_profile_id"] || turn.conversation.relationship_profile_id
      end

      def with_record_locks
        target&.subject&.lock!
        super
      end

      def precondition
        if arguments.key?("corrected_title") && target.action_key != "review_extracted_memory"
          raise InvalidArguments
        end
        super
      end

      def search
        authorize!(ApprovalRequest, :index)
        ::ApprovalQueue::Synchronize.call(user:)
        relation = user.approval_requests
        if profile
          relation = relation.where(subject_type: "MemoryRecord", subject_id: profile.memory_records.select(:id)).or(
            relation.where(subject_type: "ExtractedMemory", subject_id: profile.extracted_memories.select(:id)))
        end
        relation = case arguments.fetch("status", "pending")
        when "deferred" then relation.deferred
        when "completed" then relation.completed
        else relation.pending_review
        end
        matches = SearchRecords.call(scope: relation.includes(subject: :relationship_profile), page: arguments.fetch("page", 1)) do |request|
          ApprovalSources.visible?(request, user:, turn:) && (!profile || request.subject.relationship_profile_id == profile.id)
        end
        records = matches.records.map do |request|
          request.subject.relationship_profile.with_lock do
            Context.observe!(turn:, profile: request.subject.relationship_profile)
            request_receipt(request)
          end
        end
        { "records" => records, "next_page" => matches.next_page }
      end

      def read
        authorize!(target, :update)
        { "record" => request_receipt(target) }
      end

      %w[approve reject edit defer dismiss].each do |decision|
        define_method(decision) do
          authorize!(target, :update)
          ::ApprovalDecisions::Apply.call(approval_request: target, actor: user, decision:,
            lock_version: arguments.fetch("lock_version"), corrected_title: arguments["corrected_title"],
            corrected_body: arguments["corrected_body"], deferred_until: arguments["deferred_until"])
          target.reload
          subject = target.subject.reload
          records = [ subject_receipt(subject) ]
          if subject.is_a?(ExtractedMemory) && subject.canonical_memory_record_id
            canonical = Sources.scope(profile:, association: :memory_records, turn:).find_by(id: subject.canonical_memory_record_id)
            records << subject_receipt(canonical) if canonical
          end
          { "record" => request_receipt(target), "records" => records }
        rescue ActiveRecord::StaleObjectError
          raise RequestConflict
        end
      end

      def preview
        raise RequestConflict unless target.open_for_decision? && ::ApprovalQueue::Eligibility.eligible?(target.subject, action_key: target.action_key)
        subject = target.subject
        effect = I18n.t("concierge.review_effect.#{target.action_key}", locale: turn.locale)
        [ effect, request_receipt(target)["title"], reviewed_body(subject), super ].compact_blank.join("\n")
      end

      private

      def request_receipt(request)
        subject = request.subject
        title = subject.is_a?(ExtractedMemory) ? subject.display_title : subject.title
        receipt(request, title:, body: reviewed_body(subject), relationship_profile_id: subject.relationship_profile_id,
          subject_type: request.subject_type, subject_id: request.subject_id, state: request.status,
          action_key: request.action_key, risk_level: request.risk_level, certainty: subject.is_a?(ExtractedMemory) ? "inferred" : request.confidence,
          lock_version: request.lock_version, deferred_until: request.deferred_until&.iso8601)
      end

      def subject_receipt(subject)
        receipt(subject, title: subject.is_a?(ExtractedMemory) ? subject.display_title : subject.title,
          body: reviewed_body(subject), certainty: subject.is_a?(ExtractedMemory) ? "inferred" : subject.confidence, state: subject.status,
          canonical_memory_record_id: subject.try(:canonical_memory_record_id))
      end

      def reviewed_body(subject)
        subject.is_a?(ExtractedMemory) && subject.corrected? ? subject.corrected_body : subject.body
      end
    end
  end
end
