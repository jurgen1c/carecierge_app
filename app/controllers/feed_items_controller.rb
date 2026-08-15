class FeedItemsController < ApplicationController
  before_action :set_feed_item

  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def dismiss
    with_locked_feed_source do
      feed_item_state
      FeedItemState.dismiss_for!(user: current_user, item_key: @feed_item.key)
    end
    redirect_to dashboard_path, notice: t("daily_feed.notices.dismissed")
  end

  def snooze
    with_locked_feed_source do
      feed_item_state
      FeedItemState.snooze_for!(user: current_user, item_key: @feed_item.key, until_time: next_local_morning)
    end
    redirect_to dashboard_path, notice: t("daily_feed.notices.snoozed")
  end

  private

  def set_feed_item
    @feed_item = DailyFeed::ForUser.find(user: current_user, item_key: params[:id])
    raise ActiveRecord::RecordNotFound unless @feed_item
  end

  def feed_item_state
    @feed_item_state ||= current_user.feed_item_states.find_or_initialize_by(item_key: @feed_item.key).tap do |state|
      authorize state, :update?
    end
  end

  def with_locked_feed_source
    current_user.with_lock do
      @feed_item.source.with_lock { yield }
    end
  end

  def next_local_morning
    time_zone_name = current_user.notification_preference&.time_zone.presence
    zone = time_zone_name ? ActiveSupport::TimeZone[time_zone_name] : Time.zone
    tomorrow = Time.current.in_time_zone(zone).to_date + 1.day
    zone.local(tomorrow.year, tomorrow.month, tomorrow.day, 9)
  end

  def not_found
    head :not_found
  end
end
