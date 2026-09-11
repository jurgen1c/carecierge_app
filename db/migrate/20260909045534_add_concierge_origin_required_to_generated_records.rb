class AddConciergeOriginRequiredToGeneratedRecords < ActiveRecord::Migration[8.1]
  TABLES = { "DraftRevision" => :draft_revisions, "RelationshipBriefing" => :relationship_briefings,
    "GiftRecommendation" => :gift_recommendations }.freeze
  ORIGIN_NAMES = %w[drafts.generate drafts.update drafts.restore briefings.generate gift_ideas.generate gift_ideas.alternative].freeze

  class StoredAction < ActiveRecord::Base
    self.table_name = "concierge_actions"
    serialize :result, coder: JSON
    encrypts :result
  end

  def up
    TABLES.each_value { |table| add_column table, :concierge_origin_required, :boolean, default: false, null: false }
    StoredAction.where(state: "succeeded", name: ORIGIN_NAMES).find_each(batch_size: 200) do |action|
      result = action.result || {}
      references = Array(result["records"]) + [ result["record"] ].compact
      references.each do |reference|
        next unless reference.is_a?(Hash) && TABLES.key?(reference["record_type"]) && reference["id"].is_a?(String)
        table = quote_table_name(TABLES.fetch(reference["record_type"]))
        execute "UPDATE #{table} SET concierge_origin_required = TRUE WHERE id = #{quote(reference['id'])}"
      end
    end
  end

  def down
    TABLES.each_value { |table| remove_column table, :concierge_origin_required }
  end
end
