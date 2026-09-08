class DashboardController < ApplicationController
  def index
    @onboarding_available = current_user.onboarding_available?
    @today = Today::Overview.new(user: current_user)
    @daily_feed = @today.feed
  end
end
