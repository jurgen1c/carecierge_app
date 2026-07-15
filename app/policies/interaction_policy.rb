class InteractionPolicy < ApplicationPolicy
  def create?
    owns_profile? && record.manual?
  end

  def update?
    owns_profile? && record.manual?
  end

  def destroy?
    owns_profile? && record.manual?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?

      scope.joins(:relationship_profile).where(relationship_profiles: { user_id: user.id })
    end
  end

  private

  def owns_profile?
    user.present? && record.relationship_profile.user_id == user.id
  end
end
