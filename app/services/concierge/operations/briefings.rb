module Concierge
  module Operations
    class Briefings < Generated
      def self.namespace = "briefings"

      def self.definitions
        [
          define("generate", description: "Prepare a source-backed relationship briefing for a specified upcoming interaction. Uses only sensitive items selected in this conversation.",
            fields: SCOPE_FIELDS.merge(interaction_context: :string), required: %w[interaction_context], provider_work: true),
          define("search", description: "List available current relationship briefings. Follow next_page to continue.", fields: SCOPE_FIELDS.merge(page: :integer), read_only: true),
          define("read", description: "Read an identified available briefing with source references.", fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id], read_only: true),
          define("save", description: "Save an identified briefing for later.", fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id]),
          define("dismiss", description: "Dismiss an identified briefing from current suggestions.", fields: SCOPE_FIELDS.merge(id: :uuid), required: %w[id])
        ]
      end

      def scope
        profile.relationship_briefings.visible.where(relationship_mode: profile.relationship_mode)
      end

      def target
        @target ||= visible!(scope.find(arguments["id"])) if arguments["id"]
      end

      def generate(on_persist:)
        ::RelationshipBriefings::Generate.call(**generation_options, interaction_context: arguments.fetch("interaction_context"),
          on_persist: ->(briefing) do
            GeneratedSources.mark_origin!(briefing)
            retired = profile.relationship_briefings.where(status: "dismissed", relationship_mode: profile.relationship_mode,
              id: History.referenced_ids(turn, record_type: "RelationshipBriefing")).pluck(:id)
            on_persist.call(briefing_result(briefing).merge("superseded" => retired.map { |id| { "record_type" => "RelationshipBriefing", "id" => id } }))
          end)
      end

      def search
        authorize!(profile, :show)
        matches = SearchRecords.call(scope:, page: arguments.fetch("page", 1), order: { generated_at: :desc, id: :asc }) do |record|
          GeneratedSources.visible?(record, turn:)
        end
        { "records" => matches.records.map { |record| briefing_receipt(record) }, "next_page" => matches.next_page }
      end

      def read
        authorize!(profile, :show)
        briefing_result(target)
      end

      %w[save dismiss].each do |event|
        define_method(event) do
          authorize!(target, event == "save" ? :update : :destroy)
          target.public_send(event == "save" ? :save_for_later! : :dismiss!)
          AuditEvent.record!(user:, actor: user, action: "relationship_briefing.#{event == 'save' ? 'saved' : 'dismissed'}",
            target: profile, metadata: { result: target.status })
          briefing_result(target).merge("archived" => event == "dismiss")
        end
      end

      private

      def briefing_receipt(record)
        items = record.sections.flat_map { |section| section.fetch("items") }
        receipt(record, title: record.interaction_context, body: items.map { |item| item.fetch("body") }.join("\n"),
          state: record.status, certainty: "inferred", sources: items.flat_map { |item| item.fetch("sources") }.uniq)
      end

      def briefing_result(record)
        { "record" => briefing_receipt(record) }
      end
    end
  end
end
