class ReminderPolicy < ApplicationPolicy
  def index? = user.present?
  def create? = user.present? && (record.new_record? || owner?)
  def update? = owner?
  def destroy? = owner?
  def snooze? = owner?
  def complete? = owner?
  def calendar? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.where(user:)
    end
  end

  private

  def owner?
    user.present? && record.user_id == user.id
  end
end
