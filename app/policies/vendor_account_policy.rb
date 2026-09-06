class VendorAccountPolicy < ApplicationPolicy
  def create? = user.present? && user.confirmed?
  def show? = create? && record.user_id == user.id
  def update? = show?
  def submit? = show?
  def moderate? = create? && user.admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.confirmed? ? scope.where(user:) : scope.none
  end
end
