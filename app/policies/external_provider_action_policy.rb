class ExternalProviderActionPolicy < ApplicationPolicy
  def index? = owner?
  def create? = owner? && record.mutable?
  def update? = create?
  def destroy? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      user ? scope.where(user:) : scope.none
    end
  end

  private

  def owner? = user.present? && record.user_id == user.id
end
