require "digest"

module Concierge
  class Execute
    MAX_ACTIONS = 24
    APPROVAL_LIFETIME = 15.minutes

    def self.call(turn:, token:, name:, arguments:)
      operation = Catalog.fetch(name)
      arguments = operation.validate(arguments)
      user = turn.conversation.user
      result = user.with_lock("FOR NO KEY UPDATE") do
        turn.lock!
        raise ExecutionExpired unless turn.running_for?(token)
        Context.verify!(turn:)
        handler = operation.handler_class.new(turn:, arguments:)
        with_target_lock(handler) do
          Context.observe!(turn:, profile: handler.profile)
          action = turn.actions.find_or_initialize_by(fingerprint: fingerprint(name, arguments))
          raise LimitReached if action.new_record? && turn.actions.count >= MAX_ACTIONS
          check_feature!(operation, user)
          decision = permission_decision(operation, handler)
          raise PermissionDenied if decision && !decision.enabled?
          return replay_result(action, user:, turn:) if action.persisted? && !operation.read_only
          # RubyLLM retains earlier tool messages even when a different lookup
          # replaces the same source reference. Check history before every action.
          raise ContextUnavailable unless History.sources_current?(turn)

          action.assign_attributes(name:, arguments:)

          if operation.confirmation || decision&.approval_required?
            action.assign_attributes(state: "awaiting_approval", expires_at: APPROVAL_LIFETIME.from_now,
              precondition: precondition_for(operation, handler))
            action.save!
            action.update!(result: { "status" => "awaiting_approval", "action_id" => action.id,
              "operation" => operation.name, "arguments" => arguments, "preview" => handler.preview })
          elsif operation.provider_work
            action.update!(state: "pending", precondition: precondition_for(operation, handler),
              result: { "status" => "pending" })
          else
            complete!(action, handler, operation)
          end
          action.result.except("preview", "arguments")
        end
      end
      if operation.provider_work && result["status"] == "pending"
        action = turn.actions.find_by!(fingerprint: fingerprint(name, arguments))
        ProviderExecution.call(action:, turn_token: token)
      else
        result
      end
    end

    def self.replay_result(action, user:, turn:)
      references = Array(action.result["records"]) + [ action.result["record"] ].compact
      return action.result.except("preview", "arguments") if references.all? { |source| History.source_current?(source, user:, turn:) }

      { "status" => action.state, "action_id" => action.id, "source_changed" => true }
    end

    def self.complete!(action, handler, operation)
      profile_version = RecordVersion.for(handler.profile) if handler.profile
      related = operation.read_only ? [] : RelatedSources.capture(target: handler.target, turn: handler.turn, profile: handler.profile)
      value = handler.public_send(operation.action)
      refresh_profile_source!(value, handler:, previous_version: profile_version) unless operation.read_only
      retired = RelatedSources.retired(related, turn: handler.turn)
      value["superseded"] = (Array(value["superseded"]) + retired).uniq if retired.any?
      if handler.is_a?(Operations::Generated)
        value["authorization_version"] = GeneratedSources.authorization_version(profile: handler.profile, turn: handler.turn)
        if value.dig("record", "record_type") == "DraftRevision"
          value["draft_context_version"] = GeneratedSources.draft_context_version(profile: handler.profile, turn: handler.turn)
        end
      end
      action.id ||= SecureRandom.uuid
      action.update!(state: "succeeded", result: value.merge("status" => "succeeded", "action_id" => action.id))
      action.result
    end

    def self.refresh_profile_source!(value, handler:, previous_version:)
      profile = handler.profile&.reload
      return unless profile && RecordVersion.for(profile) != previous_version

      value["records"] = Array(value["records"]) + [ handler.receipt(profile, title: profile.display_name) ]
    end

    def self.with_target_lock(handler)
      profile = handler.profile
      if profile
        profile.with_lock do
          raise ContextUnavailable if profile.archived?
          ProfessionalScope.verify!(handler:)
          handler.with_record_locks { yield }
        end
      else
        ProfessionalScope.verify!(handler:)
        handler.with_record_locks { yield }
      end
    end

    def self.precondition(target)
      return {} unless target

      { "record_type" => target.class.base_class.name, "id" => target.id, "version" => RecordVersion.for(target) }
    end

    def self.precondition_for(operation, handler)
      operation.provider_work ? precondition(handler.profile) : handler.precondition
    end

    def self.check_feature!(operation, user)
      return unless operation.feature
      raise PermissionDenied unless FeatureFlag.enabled?(operation.feature, user:, environment: Rails.env)
    end

    def self.permission_decision(operation, handler)
      return unless operation.capability

      AutomationPermission.decision_for(user: handler.user, capability: operation.capability, relationship_profile: handler.profile)
    end

    def self.fingerprint(name, arguments)
      Digest::SHA256.hexdigest(JSON.generate([ name, arguments.sort.to_h ]))
    end
  end
end
