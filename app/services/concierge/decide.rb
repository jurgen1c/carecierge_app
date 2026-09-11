module Concierge
  class Decide
    def self.available?(user:, action:)
      I18n.with_locale(action.turn.locale) do
        user.with_lock("FOR NO KEY UPDATE") do
          return false unless action.state == "awaiting_approval" && action.expires_at && action.expires_at > Time.current
          Pundit.authorize(user, action.turn.conversation, :update?)
          Context.verify!(turn: action.turn)
          return false unless History.sources_current?(action.turn)
          operation = Catalog.fetch(action.name)
          handler = operation.handler_class.new(turn: action.turn, arguments: operation.validate(action.arguments))
          Execute.check_feature!(operation, user)
          permission = Execute.permission_decision(operation, handler)
          return false if permission && !permission.enabled?
          Execute.with_target_lock(handler) { Execute.precondition_for(operation, handler) == action.precondition }
        end
      end
    rescue Error, ActiveRecord::RecordNotFound, Pundit::NotAuthorizedError
      false
    end

    def self.call(user:, action:, decision:, fingerprint:)
      I18n.with_locale(action.turn.locale) do
        conversation = action.turn.conversation
        Pundit.authorize(user, conversation, :update?)
        raise InvalidArguments unless decision.in?(%w[approve reject retry])
        raise RequestConflict unless fingerprint == action.fingerprint

        user.with_lock("FOR NO KEY UPDATE") do
          action.lock!
          return action.result if action.state.in?(%w[succeeded rejected])
          return retry_action!(action, user:) if decision == "retry"
          return action.result if action.state.in?(%w[approved running])
          raise RequestConflict unless action.state == "awaiting_approval" && action.expires_at && action.expires_at > Time.current
          Context.verify!(turn: action.turn)

          if decision == "reject"
            action.update!(state: "rejected", decided_at: Time.current,
              result: { "status" => "rejected", "action_id" => action.id })
            return action.result
          end

          operation = Catalog.fetch(action.name)
          handler = operation.handler_class.new(turn: action.turn, arguments: operation.validate(action.arguments))
          Execute.check_feature!(operation, user)
          permission = Execute.permission_decision(operation, handler)
          raise PermissionDenied if permission && !permission.permits_execution?(explicitly_approved: true)
          Execute.with_target_lock(handler) do
            raise RequestConflict unless Execute.precondition_for(operation, handler) == action.precondition
            raise ContextUnavailable unless History.sources_current?(action.turn)

            action.update!(state: "approved", decided_at: Time.current)
            if operation.provider_work
              action.update!(result: { "status" => "approved", "action_id" => action.id })
              ConciergeActionJob.perform_later(action.id)
              action.result
            else
              Execute.complete!(action, handler, operation)
            end
          end
        end
      end
    end

    def self.retry_action!(action, user:)
      operation = Catalog.fetch(action.name)
      raise RequestConflict unless operation.provider_work && action.retryable?
      Context.verify!(turn: action.turn)
      handler = operation.handler_class.new(turn: action.turn, arguments: operation.validate(action.arguments))
      Execute.check_feature!(operation, user)
      permission = Execute.permission_decision(operation, handler)
      raise PermissionDenied if permission && !permission.permits_execution?(explicitly_approved: action.decided_at.present?)
      Execute.with_target_lock(handler) do
        raise RequestConflict unless Execute.precondition_for(operation, handler) == action.precondition
        # A retry is an explicit owner request, but does not replace any mandatory approval.
        action.update!(state: "approved", run_token: nil, started_at: nil, error_code: nil,
          result: { "status" => "approved", "action_id" => action.id })
        ConciergeActionJob.perform_later(action.id)
        action.result
      end
    end
  end
end
