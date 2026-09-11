module Concierge
  class SearchRecords
    PAGE_SIZE = 20
    MAX_PAGE = 1_000
    Result = Data.define(:records, :next_page)

    def self.call(scope:, predicate: nil, query: nil, page: 1, order: { updated_at: :desc, id: :asc }, &visible)
      raise InvalidArguments unless page.is_a?(Integer) && page.between?(1, MAX_PAGE)
      query = query.to_s.first(200)
      fields = predicate ? predicate.to_s.delete_suffix("_cont").split("_or_") : []
      encrypted = Array(scope.klass.encrypted_attributes).map(&:to_s)
      local_search = fields.any? { |field| encrypted.include?(field) || !scope.klass.column_names.include?(field) }
      scope = scope.ransack(predicate => query).result if predicate && !local_search
      batch = scope.reorder(order).offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE + 1).to_a
      records = batch.first(PAGE_SIZE).select do |record|
        next false if visible && !visible.call(record)
        !local_search || query.blank? || fields.any? do |field|
          value = record.public_send(field)
          text = value.respond_to?(:to_plain_text) ? value.to_plain_text : value.to_s
          text.downcase.include?(query.downcase)
        end
      end
      Result.new(records:, next_page: batch.size > PAGE_SIZE && page < MAX_PAGE ? page + 1 : nil)
    end
  end
end
