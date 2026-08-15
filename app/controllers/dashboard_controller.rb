class DashboardController < ApplicationController
  def index
    @onboarding_available = current_user.onboarding_available?
    @daily_feed = DailyFeed::ForUser.call(user: current_user)
  end
end
