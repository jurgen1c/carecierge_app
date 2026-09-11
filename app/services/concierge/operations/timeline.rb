module Concierge
  module Operations
    class Timeline < ProfileRecords
      NAMESPACE = "timeline"
      ASSOCIATION = :timeline_entries
      FIELDS = { entry_type: TimelineEntry::ENTRY_TYPES, title: :string, body: :string, occurred_at: :datetime }.freeze
      REQUIRED = %w[entry_type title occurred_at].freeze
      SEARCH = :title_or_body_cont
      TITLE = :title
      BODY = :body
    end
  end
end
