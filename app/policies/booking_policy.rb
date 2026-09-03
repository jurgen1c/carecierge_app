class BookingPolicy < ApplicationPolicy
  def index? = user.present? && (record == Booking || owner?)
  def create? = owner? && record.mutable?
  def update? = owner? && record.mutable?
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
