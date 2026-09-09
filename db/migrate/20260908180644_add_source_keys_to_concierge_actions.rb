require "digest"

class AddSourceKeysToConciergeActions < ActiveRecord::Migration[8.1]
  ORIGIN_NAMES = %w[drafts.generate drafts.update drafts.restore briefings.generate gift_ideas.generate gift_ideas.alternative].freeze
  SOURCE_TYPES = %w[DraftRevision RelationshipBriefing GiftRecommendation].freeze

  class StoredAction < ActiveRecord::Base
    self.table_name = "concierge_actions"
    serialize :result, coder: JSON
    encrypts :result
  end

  def up
    add_column :concierge_actions, :source_keys, :text, array: true, default: [], null: false
    StoredAction.reset_column_information
    StoredAction.where(state: "succeeded", name: ORIGIN_NAMES).find_each(batch_size: 200) do |action|
      result = action.result || {}
      references = Array(result["records"]) + [ result["record"] ].compact
      keys = references.filter_map do |reference|
        next unless reference.is_a?(Hash) && reference["record_type"].in?(SOURCE_TYPES) && reference["id"].is_a?(String)
        Digest::SHA256.hexdigest("#{reference['record_type']}:#{reference['id']}")
      end.uniq
      action.update_columns(source_keys: keys)
    end
    add_index :concierge_actions, :source_keys, using: :gin
  end

  def down
    remove_index :concierge_actions, :source_keys
    remove_column :concierge_actions, :source_keys
  end
end
