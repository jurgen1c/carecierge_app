require "delegate"

module Concierge
  # Reauthenticated read context over the persisted turn and its associations.
  # Rendering and export never renew the stored execution lease.
  class ReadTurn < SimpleDelegator
    attr_reader :vault_lease

    def initialize(turn:, vault_lease:)
      raise VaultLocked unless vault_lease.active_for?(turn.conversation.user)
      @vault_lease = vault_lease
      super(turn)
    end

    def context
      __getobj__.context.merge("vault_lease" => vault_lease.to_session)
    end
  end
end
