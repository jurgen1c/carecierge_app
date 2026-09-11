module Concierge
  class ProfessionalScope
    NAMESPACES = %w[people notes preferences commitments dates cadence drafts briefings gift_ideas gifts gift_purchases gift_boxes priorities reminders work ideas plans tasks plan_ideas backups touches vendors shortlists vendor_options quotes bookings].freeze

    def self.verify!(handler:)
      profile = handler.profile
      professional_turn = handler.turn.context["relationship_mode"] == "professional"
      return unless professional_turn || profile&.professional?

      raise ContextUnavailable if professional_turn && profile && !profile.professional?
      raise ContextUnavailable unless handler.class.namespace.in?(NAMESPACES)
    end

    def self.create_record!(handler:, record:)
      create_and_select!(handler:, collection: handler.class::ASSOCIATION.to_s) do
        yield
        record
      end
    end

    def self.create_and_select!(handler:, collection:)
      profile = handler.profile
      return yield unless profile.professional?

      raise ContextUnavailable unless collection.in?(ProfessionalContext::COLLECTIONS)
      context = profile.professional_context.deep_dup
      ProfessionalContext::COLLECTIONS.each do |name|
        next unless context.key?(name)
        context[name] = Array(context[name]) & profile.work_context.selected(name).pluck(:id)
      end
      selected = Array(context[collection])
      raise ContextUnavailable if selected.length >= Context::MAX_SELECTIONS

      record = yield
      raise ContextUnavailable unless record.persisted? && profile.work_context.candidates(collection).exists?(id: record.id)
      AuditEvents::Track.call(user: handler.user, actor: handler.user, action: "relationship_profile.updated", target: profile,
        metadata: { changed_fields: "profile_details" }) do
        profile.update!(professional_context: context.merge(collection => selected + [ record.id ]))
      end
      Context.observe!(turn: handler.turn, profile:)
      record.reload
    end
  end
end
