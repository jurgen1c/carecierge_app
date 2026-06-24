class FeatureFlagPolicy < ApplicationPolicy
  def index?
    user&.admin? || false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?

      scope.ordered
    end
  end
end
