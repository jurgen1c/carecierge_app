class PlanTaskPolicy < ApplicationPolicy
  def create? = owner?
  def update? = owner?
  def destroy? = owner?
  def complete? = owner?
  def reopen? = owner?

  private

  def owner?
    user.present? && record.event_plan&.user_id == user.id
  end
end
