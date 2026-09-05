class SharedRelationshipSpacePolicy < ApplicationPolicy
  def index? = user.present?
  def create? = user&.confirmed?
  def show? = record.participant?(user)
  def destroy? = show? || record.can_accept?(user)

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.participating(user)
  end
end
