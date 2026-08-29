class ApprovalRequestPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def update?
    user.present? && record.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user:)
    end
  end
end
