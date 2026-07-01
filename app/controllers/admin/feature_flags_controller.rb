module Admin
  class FeatureFlagsController < ApplicationController
    def index
      authorize FeatureFlag

      @feature_flags = policy_scope(FeatureFlag).includes(:feature_flag_assignments).to_a
      @rollout_groups = RolloutGroup.ordered.to_a
    end
  end
end
