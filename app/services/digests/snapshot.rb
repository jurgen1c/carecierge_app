module Digests
  SnapshotItem = Data.define(
    :kind, :title, :relationship_name, :relationship_profile_id,
    :due_at, :overdue, :date_type, :planning_prompt
  )

  SnapshotDigest = Data.define(:mode, :as_of, :items) do
    def empty? = items.empty?
    def start_item = items.first
    def remaining_items = items.drop(1)
  end

  module Snapshot
    module_function

    def dump(digest)
      {
        mode: digest.mode,
        as_of: digest.as_of.iso8601,
        items: digest.items.map { |item| dump_item(item) }
      }
    end

    def load(attributes)
      attributes = attributes.deep_symbolize_keys
      items = attributes.fetch(:items).map do |item|
        item = item.deep_symbolize_keys
        defaults = { date_type: nil, planning_prompt: nil }
        SnapshotItem.new(**defaults.merge(item, kind: item.fetch(:kind).to_sym, due_at: Time.iso8601(item.fetch(:due_at))))
      end
      SnapshotDigest.new(mode: attributes.fetch(:mode), as_of: Time.iso8601(attributes.fetch(:as_of)), items:)
    end

    def dump_item(item)
      important_date = item.record if item.kind.in?([ :upcoming_date, :planning_prompt ])
      {
        kind: item.kind,
        title: important_date ? important_date.title : item.title,
        relationship_name: item.relationship_name,
        relationship_profile_id: item.relationship_profile.id,
        due_at: item.due_at.iso8601,
        overdue: item.overdue,
        date_type: important_date&.date_type,
        planning_prompt: nil
      }
    end
  end
end
