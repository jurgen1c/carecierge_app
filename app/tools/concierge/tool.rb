module Concierge
  class Tool < RubyLLM::Tool
    def initialize(operation:, turn:, token:)
      @operation, @turn, @token = operation, turn, token
    end

    def name = @operation.name.tr(".", "_")
    def description = @operation.description
    def params_schema
      schema = @operation.schema
      return schema if @turn&.conversation&.relationship_profile_id.present?
      return schema unless @operation.fields.key?("relationship_profile_id")
      return schema unless @operation.handler_class::REQUIRES_PROFILE_ID

      schema[:required] = (schema.fetch(:required) + [ "relationship_profile_id" ]).uniq
      schema[:properties]["relationship_profile_id"][:description] = "Call people_search first and use the exact UUID returned for the intended person."
      schema
    end

    # The gem's default call logs complete arguments/results at debug level.
    # This boundary deliberately emits only the application's content-free events.
    def call(arguments)
      Execute.call(turn: @turn, token: @token, name: @operation.name, arguments:)
    rescue InvalidArguments
      { "status" => "invalid_arguments", "instruction" => "Ask for the missing or invalid detail; do not guess." }
    rescue ActiveRecord::RecordNotFound, Pundit::NotAuthorizedError
      { "status" => "unavailable", "instruction" => "This record is not available in the authorized scope." }
    rescue ActiveRecord::RecordInvalid => error
      { "status" => "invalid_record", "fields" => error.record.errors.attribute_names.map(&:to_s),
        "instruction" => "Ask the user to clarify these fields. Nothing was saved." }
    rescue PermissionDenied
      { "status" => "permission_required", "instruction" => "The capability is disabled. Explain how to review permissions." }
    end
  end
end
