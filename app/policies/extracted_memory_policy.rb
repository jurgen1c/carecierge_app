class ExtractedMemoryPolicy < ApplicationPolicy
  def review?
    user.present? && record.relationship_profile.user_id == user.id
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?

      scope.joins(:relationship_profile).where(relationship_profiles: { user_id: user.id })
    end
  end
end
