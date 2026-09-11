module Concierge
  class ApprovalSources
    TYPES = { "MemoryRecord" => :memory_records, "ExtractedMemory" => :extracted_memories }.freeze

    def self.visible?(request, user:, turn:)
      return false unless request && request.user_id == user.id && TYPES.key?(request.subject_type)
      subject = request.subject
      profile = subject&.relationship_profile
      return false unless profile && profile.user_id == user.id && !profile.archived? && !profile.professional?
      return false unless request.action_key == ::ApprovalQueue::Eligibility.action_key(subject)

      Sources.scope(profile:, association: TYPES.fetch(request.subject_type), turn:).exists?(id: subject.id)
    end

    def self.find(reference, user:, turn:)
      request = user.approval_requests.find_by(id: reference["id"])
      request if visible?(request, user:, turn:)
    end
  end
end
