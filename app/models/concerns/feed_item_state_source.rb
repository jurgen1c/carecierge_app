module FeedItemStateSource
  extend ActiveSupport::Concern

  included do
    after_destroy :delete_feed_item_states
  end

  private

  def delete_feed_item_states
    FeedItemState.delete_for_source!(self)
  end
end
