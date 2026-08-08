module DataExports
  class CsvSerializer
    def initialize(snapshot)
      @snapshot = snapshot
    end

    def to_csv
      rows = [ %w[path value], *flatten(snapshot) ]
      rows.map { |row| row.map { |value| csv_cell(value) }.join(",") }.join("\r\n") + "\r\n"
    end

    private

    attr_reader :snapshot

    def flatten(value, path = nil)
      case value
      when Hash
        value.flat_map { |key, nested| flatten(nested, [ path, key ].compact.join(".")) }
      when Array
        value.each_with_index.flat_map { |nested, index| flatten(nested, "#{path}[#{index}]") }
      else
        [ [ path, scalar(value) ] ]
      end
    end

    def scalar(value)
      value.respond_to?(:iso8601) ? value.iso8601 : value
    end

    def csv_cell(value)
      text = value.to_s
      text = "'#{text}" if text.match?(/\A[\s]*[=+\-@]/)
      %Q("#{text.gsub('"', '""')}")
    end
  end
end
