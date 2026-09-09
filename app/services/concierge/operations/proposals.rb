module Concierge
  module Operations
    class Proposals < Base
      def self.namespace = "proposals"

      def self.definitions
        [ define("search", description: "List pending extracted memory proposals. These are unconfirmed interpretations, never established facts.",
           fields: { relationship_profile_id: :uuid, page: :integer }, read_only: true),
         define("review", description: "Prepare approval, rejection, or a correction of an extracted proposal. The owner reviews the exact change inline.",
           fields: { relationship_profile_id: :uuid, id: :uuid, decision: %w[approve reject correct], corrected_title: :string, corrected_body: :string },
           required: %w[id decision], confirmation: true) ]
      end

      def target
        @target ||= Sources.scope(profile:, association: :extracted_memories, turn:).find(arguments["id"]) if arguments["id"]
      end

      def search
        authorize!(profile, :show)
        matches = SearchRecords.call(scope: Sources.scope(profile:, association: :extracted_memories, turn:).pending_review, page: arguments.fetch("page", 1))
        { "records" => matches.records.map { |record| proposal_receipt(record) }, "next_page" => matches.next_page }
      end

      def review
        authorize!(target, :review)
        raise RequestConflict unless target.pending?
        ApprovalQueue::RecordSourceDecision.call(user:, subject: target, decision: arguments.fetch("decision"),
          corrected_title: arguments["corrected_title"], corrected_body: arguments["corrected_body"])
        { "record" => proposal_receipt(target.reload) }
      rescue ApprovalQueue::RecordSourceDecision::DecisionConflict
        raise RequestConflict
      end

      private

      def proposal_receipt(record)
        receipt(record, title: record.display_title, body: record.corrected? ? record.corrected_body : record.body,
          review_status: record.status, certainty: "inferred", source: "ai_inferred",
          canonical_memory_record_id: record.canonical_memory_record_id)
      end
    end
  end
end
