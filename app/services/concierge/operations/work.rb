module Concierge
  module Operations
    class Work < Base
      FIELDS = ProfessionalContext::FIELDS.index_with { :string }.symbolize_keys.merge(gifts_allowed: :boolean).freeze

      def self.namespace = "work"

      def self.definitions
        [ define("read", description: "Read this person's selected work context and professional boundaries. Excludes personal information.",
            fields: { relationship_profile_id: :uuid }, read_only: true),
          define("update", description: "Preview changing professional context and gift suitability. Requires exact inline review; preserves existing work source selections. Never changes relationship mode.",
            fields: FIELDS.merge(relationship_profile_id: :uuid), confirmation: true) ]
      end

      def profile
        record = super
        raise ContextUnavailable unless record.professional?
        record
      end

      def target = profile

      def read
        authorize!(profile, :show)
        work_result
      end

      def update
        authorize!(profile, :update)
        changes = attributes
        changes["gifts_allowed"] = changes["gifts_allowed"] ? "1" : "0" if changes.key?("gifts_allowed")
        AuditEvents::Track.call(user:, actor: user, action: "relationship_profile.updated", target: profile,
          metadata: { changed_fields: "profile_details" }) do
          profile.update!(professional_context: profile.professional_context.merge(changes))
        end
        Context.observe!(turn:, profile:)
        work_result
      end

      def preview
        [ profile.display_name, profile.professional_context.slice(*ProfessionalContext::FIELDS).values.join("\n"), super ].compact_blank.join("\n")
      end

      private

      def work_result
        fields = profile.professional_context.slice(*ProfessionalContext::FIELDS)
        result(profile, title: profile.display_name, body: fields.values.compact_blank.join("\n"), **fields,
          gifts_allowed: profile.professional_gifts_allowed?, relationship_mode: "professional",
          selected_sources: profile.professional_context.slice(*ProfessionalContext::COLLECTIONS))
      end
    end
  end
end
