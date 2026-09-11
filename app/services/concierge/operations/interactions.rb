module Concierge
  module Operations
    class Interactions < ProfileRecords
      NAMESPACE = "interactions"
      ASSOCIATION = :interactions
      FIELDS = { interaction_type: Interaction::MANUAL_TYPES, occurred_at: :datetime, notes: :string }.freeze
      REQUIRED = %w[interaction_type occurred_at].freeze
      SEARCH = :display_notes_cont
      TITLE = :interaction_type
      BODY = :display_notes

      def scope
        super.includes(:source)
      end
    end
  end
end
