class PersonalTouchChecklistPolicy < ApplicationPolicy
  def show? = owner?
  def create? = owner?
  def update? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope
        .joins(:relationship_profile)
        .where(relationship_profiles: { user_id: user.id, discarded_at: nil })
    end
  end

  private

  def owner?
    user.present? && record.relationship_profile&.user_id == user.id && !record.relationship_profile.discarded?
  end
end
