module Concierge
  module Operations
    class Base
      LIMIT = 20
      CLEARABLE_FIELDS = [].freeze
      REQUIRES_PROFILE_ID = true

      attr_reader :turn, :arguments

      def initialize(turn:, arguments:)
        @turn, @arguments = turn, arguments
      end

      def user
        turn.conversation.user
      end

      def profile
        @profile ||= user.relationship_profiles.active.find(arguments["relationship_profile_id"].presence || turn.conversation.relationship_profile_id)
      end

      def target
        nil
      end

      def with_record_locks
        target&.lock! unless target == profile
        yield
      end

      def precondition
        Execute.precondition(target)
      end

      def preview
        before = if target
          %i[display_name display_title title name key body notes observation].filter_map do |field|
            next unless target.respond_to?(field)
            value = target.public_send(field)
            value.respond_to?(:to_plain_text) ? value.to_plain_text : value.to_s
          end
        else
          []
        end
        proposed = arguments.except("id", "relationship_profile_id").values.map(&:to_s)
        (before + proposed).compact_blank.uniq.join(" · ")
      end

      def authorize!(record, action)
        Pundit.authorize(user, record, "#{action}?")
      end

      def receipt(record, title:, body: nil, **metadata)
        { "record_type" => record.class.base_class.name, "id" => record.id,
          "version" => RecordVersion.for(record),
          "relationship_profile_id" => record.is_a?(RelationshipProfile) ? record.id : record.try(:relationship_profile_id),
          "title" => title.to_s.first(200), "body" => body&.to_s&.first(1_500) }
          .merge(metadata.stringify_keys.except("record_type", "id", "version", "title", "body")).compact
      end

      def result(record, **options)
        { "record" => receipt(record, **options) }
      end

      def attributes
        arguments.except("id", "relationship_profile_id", "query")
      end

      def self.define(action, **options)
        if action.in?(%w[update save update_item])
          options[:nullable] = self::CLEARABLE_FIELDS & options.fetch(:fields).keys.map(&:to_s)
        end
        Operation.new(name: "#{namespace}.#{action}", handler_class: self, **options)
      end
    end
  end
end
