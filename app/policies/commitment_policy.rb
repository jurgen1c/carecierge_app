class CommitmentPolicy < ApplicationPolicy
  def create? = owns_profile?
  def update? = owns_profile?
  def destroy? = owns_profile?
  def complete? = owns_profile?
  def cancel? = owns_profile?
  def reopen? = owns_profile?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.joins(:relationship_profile).where(relationship_profiles: { user_id: user.id })
    end
  end

  private

  def owns_profile?
    user.present? && record.relationship_profile.user_id == user.id
  end
end
