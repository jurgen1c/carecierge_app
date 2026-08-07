class AutomationPermissionPolicy < ApplicationPolicy
  def edit?
    user.present? && (record == AutomationPermission || owner?)
  end

  def create?
    edit?
  end

  def update?
    edit?
  end

  def destroy?
    user.present? && record != AutomationPermission && owner?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.where(user:)
    end
  end

  private

  def owner?
    record.user_id == user.id
  end
end
