module Admin
  class FeatureFlagsController < ApplicationController
    before_action :authenticate_user!

    def index
      authorize FeatureFlag

      @feature_flags = policy_scope(FeatureFlag).includes(:feature_flag_assignments)
      @rollout_groups = RolloutGroup.ordered
    end
  end
end
