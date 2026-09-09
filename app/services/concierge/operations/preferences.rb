module Concierge
  module Operations
    class Preferences < ProfileRecords
      CLEARABLE_FIELDS = %w[learned_on source_notes].freeze
      NAMESPACE = "preferences"
      ASSOCIATION = :relationship_preferences
      FIELDS = { key: :string, value: :string, preference_type: RelationshipPreference.preference_types.keys,
        category: RelationshipPreference.categories.keys, confidence: RelationshipPreference.confidences.keys,
        learned_on: :date, source_notes: :string }.freeze
      REQUIRED = %w[key value].freeze
      SEARCH = :key_or_value_cont
      TITLE = :key
      BODY = :value

      private

      def authorize_record!(_record, _action)
        authorize!(profile, :update)
      end
    end
  end
end
