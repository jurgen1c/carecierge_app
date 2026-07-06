class DashboardController < ApplicationController
  def index
    @onboarding_available = current_user.onboarding_available?
  end
end
