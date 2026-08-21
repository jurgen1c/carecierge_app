class GiftRecommendationPolicy < ApplicationPolicy
  def update?
    record.user_id == user.id && record.relationship_profile.user_id == user.id
  end

  def destroy?
    update?
  end
end
