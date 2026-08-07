class AuditEventPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def admin_index?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.admin?

      scope.all
    end
  end
end
