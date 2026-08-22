class PersonalTouchItemPolicy < ApplicationPolicy
  def create? = owner?
  def update? = owner?
  def complete? = owner?
  def reopen? = owner?
  def dismiss? = owner?
  def move_up? = owner?
  def move_down? = owner?

  private

  def owner?
    checklist = record.personal_touch_checklist
    user.present? && checklist&.relationship_profile&.user_id == user.id && !checklist.relationship_profile.discarded?
  end
end
