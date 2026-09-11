module Concierge
  # Domain generators release their locks while calling providers. Their persistence
  # callback writes the action outcome in the SAME transaction as the generated records.
  class ProviderExecution
    def self.call(action:, turn_token: nil)
      new(action:, turn_token:).call
    end

    def initialize(action:, turn_token:)
      @action, @turn_token = action, turn_token
      @turn = action.turn
      @user = @turn.conversation.user
      @operation = Catalog.fetch(action.name)
      @handler = @operation.handler_class.new(turn: @turn, arguments: @operation.validate(action.arguments))
    end

    def call
      return Execute.replay_result(action, user:, turn:) unless claim!

      I18n.with_locale(turn.locale) do
        Time.use_zone(OwnerLocalCalendar.time_zone_for(user:)) do
          handler.execution_action = action
          handler.public_send(operation.action, on_persist: method(:persist_result!))
        end
      end
      raise ProviderUnavailable unless action.reload.state == "succeeded"
      action.result
    rescue ActiveRecord::RecordNotFound
      fail_action!("context_unavailable")
    rescue StandardError => error
      # Never retain provider bodies, arguments, or exception text in the ledger/log.
      fail_action!(error.is_a?(Error) ? error.code : "provider_unavailable")
    end

    private

    attr_reader :action, :turn, :user, :operation, :handler, :turn_token

    def claim!
      user.with_lock("FOR NO KEY UPDATE") do
        action.lock!
        return false unless operation.provider_work && action.state.in?(%w[pending approved])
        raise LimitReached if action.attempts >= ConciergeAction::MAX_ATTEMPTS
        verify!
        if action.state == "pending"
          raise ExecutionExpired unless turn.reload.running_for?(turn_token)
        end
        Execute.with_target_lock(handler) do
          raise RequestConflict unless Execute.precondition_for(operation, handler) == action.precondition
          @profile_version = RecordVersion.for(handler.profile) if handler.profile
          @run_token = SecureRandom.uuid
          action.update!(state: "running", run_token: @run_token, started_at: Time.current,
            attempts: action.attempts + 1, error_code: nil,
            result: { "status" => "running", "action_id" => action.id })
        end
      end
      true
    end

    def verify!
      Context.verify!(turn:)
      Execute.check_feature!(operation, user)
      permission = Execute.permission_decision(operation, handler)
      raise PermissionDenied if permission && !permission.permits_execution?(explicitly_approved: action.decided_at.present?)
      raise ContextUnavailable unless History.sources_current?(turn)
    end

    def persist_result!(value)
      # Caller must hold its owner/domain locks and an open persistence transaction.
      raise ProviderUnavailable unless ActiveRecord::Base.connection.transaction_open?
      action.lock!
      raise ExecutionExpired unless action.state == "running" && action.run_token == @run_token
      raise ExecutionExpired if turn_token && !turn.reload.running_for?(turn_token)
      Execute.refresh_profile_source!(value, handler:, previous_version: @profile_version)
      if value.dig("record", "record_type") == "DraftRevision"
        value["draft_context_version"] = GeneratedSources.draft_context_version(profile: handler.profile, turn:)
      end
      sources = GeneratedSources.generation_sources(profile: handler.profile, turn:, value:)
      value["generation_sources"] = sources if sources
      action.update!(state: "succeeded", run_token: nil,
        result: value.merge("status" => "succeeded", "action_id" => action.id,
          "authorization_version" => GeneratedSources.authorization_version(profile: handler.profile, turn:)))
      verify!
    end

    def fail_action!(code)
      user.with_lock("FOR NO KEY UPDATE") do
        # Rollback restores the row but can leave attempted result changes on this
        # instance. Reload under lock before inspecting the persisted execution lease.
        action.reload(lock: true)
        if action.state.in?(%w[pending approved]) || (action.state == "running" && action.run_token == @run_token)
          action.update!(state: "failed", run_token: nil, error_code: code,
            result: { "status" => "failed", "action_id" => action.id, "error_code" => code })
          ActiveSupport::Notifications.instrument("concierge.action_failed", operation: action.name, error_code: code)
        end
        action.result
      end
    rescue ActiveRecord::RecordNotFound
      { "status" => "unavailable" }
    end
  end
end
