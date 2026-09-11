class ConciergeConversationPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def create?
    user.present? && record.user_id == user.id && record.context_available?
  end

  def show?
    user.present? && record.user_id == user.id
  end

  def update?
    show? && record.context_available?
  end

  def destroy?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user ? scope.where(user:) : scope.none
    end
  end
end
