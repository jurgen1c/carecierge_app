class SocialContextNotePolicy < ApplicationPolicy
  def create?
    owns_active_profile?
  end

  def update?
    owns_active_profile?
  end

  def analyze?
    update?
  end

  def destroy?
    owns_active_profile?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?

      scope.joins(:relationship_profile).where(relationship_profiles: { user_id: user.id, discarded_at: nil })
    end
  end

  private

  def owns_active_profile?
    profile = record.relationship_profile
    user.present? && profile.user_id == user.id && !profile.discarded?
  end
end
