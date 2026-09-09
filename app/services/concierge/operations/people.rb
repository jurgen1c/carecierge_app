module Concierge
  module Operations
    class People < Base
      CLEARABLE_FIELDS = %w[birthday last_name preferred_name pronouns custom_type_label].freeze
      FIELDS = { first_name: :string, last_name: :string, preferred_name: :string,
        pronouns: :string, birthday: :date, type: RelationshipProfile::TYPE_LABELS.keys, custom_type_label: :string }.freeze

      def self.namespace = "people"

      def self.definitions
        [
          define("search", description: "Find people by name. Follow next_page for more matches; ask the user to choose if ambiguous.", fields: { query: :string, page: :integer }, read_only: true),
          define("clarify", description: "Show inline person choices when several authorized people match the request. Pass two to twenty exact IDs returned by search, ask which person, and stop until the owner chooses. Never execute the ambiguous change first.", fields: { ids: :uuid_list }, required: %w[ids], read_only: true),
          define("read", description: "Read an identified person's basic profile.", fields: { id: :uuid }, required: %w[id], read_only: true),
          define("create", description: "Create a relationship explicitly requested by the user.", fields: FIELDS, required: %w[first_name]),
          define("update", description: "Update the identified person's basic details.", fields: FIELDS.merge(id: :uuid), required: %w[id]),
          define("archive", description: "Preview archiving a person; the user must confirm the stored action.", fields: { id: :uuid }, required: %w[id], confirmation: true)
        ]
      end

      def profile
        target
      end

      def target
        @target ||= user.relationship_profiles.active.find(arguments["id"]) if arguments["id"]
      end

      def search
        authorize!(RelationshipProfile, :index)
        scope = user.relationship_profiles.active
        scope = scope.where(relationship_mode: "professional") if turn.context["relationship_mode"] == "professional"
        matches = SearchRecords.call(scope:, predicate: :first_name_or_last_name_or_preferred_name_cont, query: arguments["query"], page: arguments.fetch("page", 1))
        { "records" => matches.records.map { |record| profile_receipt(record) }, "next_page" => matches.next_page }
      end

      def read
        authorize!(target, :show)
        { "record" => profile_receipt(target) }
      end

      def clarify
        authorize!(RelationshipProfile, :index)
        ids = arguments.fetch("ids").uniq
        raise InvalidArguments unless ids.size.between?(2, LIMIT)
        scope = user.relationship_profiles.active
        scope = scope.where(relationship_mode: "professional") if turn.context["relationship_mode"] == "professional"
        records = scope.where(id: ids).ordered.to_a
        raise ActiveRecord::RecordNotFound unless records.size == ids.size
        { "records" => records.map { |record| profile_receipt(record) } }
      end

      def create
        mode = turn.context["relationship_mode"] == "professional" ? "professional" : "personal"
        raise ContextUnavailable if mode == "professional" && arguments.key?("birthday")
        record = user.relationship_profiles.new(attributes.merge("relationship_mode" => mode))
        authorize!(record, :create)
        track(record, "created") { record.save! }
        { "record" => profile_receipt(record) }
      end

      def update
        authorize!(target, :update)
        raise ContextUnavailable if target.professional? && arguments.key?("birthday")
        track(target, "updated") { target.update!(attributes) }
        { "record" => profile_receipt(target) }
      end

      def archive
        authorize!(target, :archive)
        track(target, "archived") { target.archive! }
        { "record" => profile_receipt(target), "archived" => true }
      end

      private

      def profile_receipt(record)
        receipt(record, title: record.display_name, relationship_mode: record.relationship_mode,
          relationship_type: record.type, birthday: record.professional? ? nil : record.birthday&.iso8601)
      end

      def track(record, event, &block)
        AuditEvents::Track.call(user:, actor: user, action: "relationship_profile.#{event}", target: record, &block)
      end
    end
  end
end
