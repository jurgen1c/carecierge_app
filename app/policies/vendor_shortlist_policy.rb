class VendorShortlistPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = owner?
  def create? = owner?
  def update? = owner? && record.mutable?
  def remove_options? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.where(user:)
    end
  end

  private

  def owner? = user.present? && record.user_id == user.id
end
