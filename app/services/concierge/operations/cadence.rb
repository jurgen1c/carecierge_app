module Concierge
  module Operations
    class Cadence < Base
      def self.namespace = "cadence"

      def self.definitions
        [ define("read", description: "Read the saved contact rhythm and last interaction time.",
           fields: { relationship_profile_id: :uuid }, read_only: true),
         define("save", description: "Set the user's requested contact rhythm, in days: 7, 14, 30, 60, or 90.",
           fields: { relationship_profile_id: :uuid, interval_days: :integer }, required: %w[interval_days]) ]
      end

      def target
        profile.contact_cadence
      end

      def read
        authorize!(profile, :show)
        return { "records" => [] } unless target
        cadence_result(target)
      end

      def save
        record = target || profile.build_contact_cadence
        authorize!(record, record.persisted? ? :update : :create)
        record.update!(interval_days: arguments.fetch("interval_days"))
        cadence_result(record)
      end

      private

      def cadence_result(record)
        last_interaction_at = profile.interactions.maximum(:occurred_at) unless profile.professional?
        result(record, title: profile.display_name, interval_days: record.interval_days, last_interaction_at: last_interaction_at&.iso8601)
      end
    end
  end
end
