module Concierge
  module Operations
    class Generated < Base
      attr_accessor :execution_action
      SCOPE_FIELDS = { relationship_profile_id: :uuid }.freeze

      def generation_options
        authorize!(profile, :update)
        Context.verify!(turn:)
        selected_profile = turn.context["relationship_profile_id"] == profile.id
        {
          actor: user, relationship_profile: profile, expected_relationship_mode: profile.relationship_mode,
          private_note_ids: selected_profile ? Array(turn.context["private_note_ids"]) : [],
          vault_item_ids: selected_profile ? Array(turn.context["vault_item_ids"]) : [],
          vault_lease: selected_profile ? PrivacyVault::Lease.from_session(turn.context["vault_lease"]) : nil,
          locale: turn.locale.to_sym
        }
      end

      def visible!(record)
        raise ActiveRecord::RecordNotFound unless GeneratedSources.visible?(record, turn:)
        record
      end
    end
  end
end
