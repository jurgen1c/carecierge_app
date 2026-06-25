class FeatureFlagPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?

      scope.ordered
    end
  end
end
