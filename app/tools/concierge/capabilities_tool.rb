module Concierge
  class CapabilitiesTool < Tool
    CORE = %w[people.search people.read memories.search memories.create].freeze
    MAX_SELECTIONS = 2

    def initialize(chat:, turn:, token:)
      @chat, @turn, @token = chat, turn, token
    end

    def name = "capabilities"

    def description
      catalog = Catalog.all.group_by { |operation| operation.name.split(".").first }.map do |name, operations|
        "#{name}: #{operations.map(&:action).join(', ')}"
      end.join("\n")
      "Load up to two capability groups to use their individual tools on the next step. Core people lookup and memory tools remain available. " \
        "Other previously loaded groups are replaced; load them again when needed. Loading tools changes no application data.\n#{catalog}"
    end

    def params_schema
      names = Catalog.all.map { |operation| operation.name.split(".").first }.uniq
      { type: "object", required: [ "capabilities" ], additionalProperties: false,
        properties: { capabilities: { type: "array", minItems: 1, maxItems: MAX_SELECTIONS,
          items: { type: "string", enum: names } } } }
    end

    def call(arguments)
      raise InvalidArguments unless arguments.is_a?(Hash) && arguments.keys.map(&:to_s) == [ "capabilities" ]
      names = arguments.with_indifferent_access[:capabilities]
      allowed = params_schema.dig(:properties, :capabilities, :items, :enum)
      raise InvalidArguments unless names.is_a?(Array) && names.size.between?(1, MAX_SELECTIONS)
      raise InvalidArguments unless names.all? { |name| name.is_a?(String) && allowed.include?(name) }

      tools = Catalog.tools(turn: @turn, token: @token, operation_names: CORE) + Catalog.tools(turn: @turn, token: @token, names:)
      tools = (tools + [ self ]).uniq(&:name)
      @chat.with_tools(*tools, replace: true, concurrency: false)
      { "status" => "ready", "enabled_tools" => tools.map(&:name) }
    rescue InvalidArguments
      { "status" => "invalid_arguments", "instruction" => "Choose one or two listed capability groups." }
    end
  end
end
