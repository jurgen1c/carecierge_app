module Concierge
  module Operations
    # Explicit subclasses supply a fixed association, attributes, and policy boundary.
    class ProfileRecords < Base
      SCOPE_FIELDS = { relationship_profile_id: :uuid }.freeze

      def self.namespace = self::NAMESPACE

      def self.definitions
        scope = SCOPE_FIELDS
        writes = scope.merge(self::FIELDS)
        [
          define("search", description: "Find authorized #{namespace} for a person. Return source references; clarify multiple matches. Follow next_page to continue searching older records, including an empty page when more records remain.", fields: scope.merge(query: :string, page: :integer), read_only: true),
          define("read", description: "Read one identified #{namespace} record.", fields: scope.merge(id: :uuid), required: %w[id], read_only: true),
          define("create", description: "Record #{namespace} explicitly requested by the user.", fields: writes, required: self::REQUIRED),
          define("update", description: "Update an identified #{namespace} record with the user's correction.", fields: writes.merge(id: :uuid), required: %w[id]),
          define("destroy", description: "Preview removing #{namespace}; requires inline confirmation.", fields: scope.merge(id: :uuid), required: %w[id], confirmation: true)
        ]
      end

      def scope
        Sources.scope(profile:, association: self.class::ASSOCIATION, turn:)
      end

      def target
        @target ||= scope.find(arguments["id"]) if arguments["id"]
      end

      def search
        authorize!(profile, :show)
        matches = SearchRecords.call(scope:, predicate: self.class::SEARCH, query: arguments["query"], page: arguments.fetch("page", 1)) { |record| search_visible?(record) }
        { "records" => matches.records.map { |record| record_receipt(record) }, "next_page" => matches.next_page }
      end

      def read
        authorize!(profile, :show)
        { "record" => record_receipt(target) }
      end

      def create
        record = profile.public_send(self.class::ASSOCIATION).build
        authorize_record!(record, :create)
        ProfessionalScope.create_record!(handler: self, record:) { persist!(record) }
        { "record" => record_receipt(record) }
      end

      def update
        authorize_record!(target, :update)
        persist!(target)
        { "record" => record_receipt(target) }
      end

      def destroy
        authorize_record!(target, :destroy)
        value = record_receipt(target)
        target.destroy!
        { "record" => value, "deleted" => true }
      end

      def record_receipt(record)
        receipt(record, title: record.public_send(self.class::TITLE), body: record.public_send(self.class::BODY),
          **record.attributes.slice(*self.class::FIELDS.keys.map(&:to_s)).except(self.class::TITLE.to_s, self.class::BODY.to_s))
      end

      private

      def search_visible?(_record) = true

      def authorize_record!(record, action)
        authorize!(record, action)
      end

      def persist!(record)
        record.assign_attributes(attributes)
        record.save!
      end
    end
  end
end
