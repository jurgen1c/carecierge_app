module Concierge
  class Operation
    attr_reader :name, :description, :handler_class, :fields, :required, :nullable, :read_only, :confirmation, :capability, :feature, :provider_work

    def initialize(name:, description:, handler_class:, fields: {}, required: [], nullable: [], read_only: false, confirmation: false, capability: nil, feature: nil, provider_work: false)
      @name, @description, @handler_class = name, description, handler_class
      @fields, @required = fields.stringify_keys.freeze, required.map(&:to_s).freeze
      @nullable = nullable.map(&:to_s).freeze
      @read_only, @confirmation, @capability, @feature = read_only, confirmation, capability, feature
      @provider_work = provider_work
    end

    def action
      name.split(".").last
    end

    def validate(arguments)
      raise InvalidArguments unless arguments.is_a?(Hash)
      values = arguments.deep_stringify_keys
      raise InvalidArguments unless (values.keys - fields.keys).empty? && (required - values.keys).empty?
      fields.each do |key, type|
        value = values[key]
        next unless values.key?(key)
        next if value.nil? && nullable.include?(key)
        valid = case type
        when :uuid then value.is_a?(String) && value.match?(RelationshipMemorySearch::SearchQuery::ID_FORMAT)
        when :uuid_list then value.is_a?(Array) && value.length <= 20 && value.all? { |id| id.is_a?(String) && id.match?(RelationshipMemorySearch::SearchQuery::ID_FORMAT) }
        when :integer then value.is_a?(Integer)
        when :boolean then value == true || value == false
        when :date then valid_date?(value)
        when :datetime then valid_time?(value)
        when Array then type.include?(value)
        else value.is_a?(String) && value.length <= 8_000 && value.valid_encoding? && !value.include?("\0")
        end
        raise InvalidArguments unless valid
      end
      values
    end

    def schema
      properties = fields.to_h do |key, type|
        property = case type
        when :integer then { type: "integer" }
        when :uuid_list then { type: "array", items: { type: "string" }, maxItems: 20 }
        when :boolean then { type: "boolean" }
        when Array then { type: "string", enum: type }
        else { type: "string" }
        end
        property[:description] = "An exact UUID returned by an authorized lookup" if type == :uuid
        property[:description] = "An exact ISO date YYYY-MM-DD; clarify ambiguous dates" if type == :date
        property[:description] = "An exact ISO timestamp with UTC offset, in the owner's time zone; clarify ambiguous times" if type == :datetime
        if nullable.include?(key)
          property[:type] = [ property[:type], "null" ]
          property[:description] = [ property[:description], "Send null to clear this saved field; omit it to preserve the existing value." ].compact.join(". ")
        end
        [ key, property ]
      end
      { type: "object", properties:, required:, additionalProperties: false }
    end

    private

    def valid_date?(value)
      value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/) && Date.iso8601(value)
    rescue ArgumentError
      false
    end

    def valid_time?(value)
      value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})\z/) && Date.iso8601(value.first(10)) && Time.iso8601(value)
    rescue ArgumentError
      false
    end
  end
end
