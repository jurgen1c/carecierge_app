class VendorPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = owner?
  def create? = owner?
  def update? = owner?
  def destroy? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.where(user:)
    end
  end

  private

  def owner? = user.present? && record.user_id == user.id
end
