class ConciergeContextOptionsComponent < ApplicationViewComponent
  option :kind
  option :records
  option :pagination

  style :link do
    base { %w[workspace-action workspace-action-secondary] }
  end

  def frame_id(number) = "concierge_#{kind}_#{number}"
  def field = kind == "private_notes" ? "private_note_ids" : "vault_item_ids"
  def label(record) = kind == "private_notes" ? record.body.to_plain_text.truncate(80) : record.display_title

  def next_path
    helpers.concierge_page_path(context_kind: kind, **{ "#{kind}_page".to_sym => pagination.next })
  end
end
