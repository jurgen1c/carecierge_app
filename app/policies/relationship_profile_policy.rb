class RelationshipProfilePolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    owns_record?
  end

  def create?
    user.present?
  end

  def update?
    owns_record?
  end

  def destroy?
    owns_record?
  end

  def archive?
    owns_record?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user:)
    end
  end

  private

  def owns_record?
    user.present? && record.user_id == user.id
  end
end
