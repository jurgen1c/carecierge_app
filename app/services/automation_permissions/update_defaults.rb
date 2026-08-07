module AutomationPermissions
  class UpdateDefaults
    def self.call(user:, actor:, modes:)
      new(user:, actor:, modes:).call
    end

    def initialize(user:, actor:, modes:)
      @user = user
      @actor = actor
      @modes = modes.to_h.stringify_keys
    end

    def call
      Change.call_defaults(user:, actor:, modes:)
      true
    end

    private

    attr_reader :actor, :modes, :user
  end
end
