module FeatureFlags
  class Context
    attr_reader :user, :account, :segment, :rollout_group, :environment

    def initialize(user: nil, account: nil, segment: nil, rollout_group: nil, environment: Rails.env)
      @user = user
      @account = account
      @segment = segment
      @rollout_group = rollout_group
      @environment = environment
    end

    def value_for(kind)
      case kind
      when "user"
        identifier_for(user)
      when "account"
        identifier_for(account)
      when "segment"
        segment.presence
      when "rollout_group"
        identifier_for(rollout_group)
      when "environment"
        environment.to_s.presence
      when "global"
        "all"
      end
    end

    private

    def identifier_for(value)
      return if value.blank?

      if value.respond_to?(:key) && value.method(:key).arity.zero?
        value.key.to_s
      elsif value.respond_to?(:id)
        value.id.to_s
      else
        value.to_s
      end
    end
  end
end
